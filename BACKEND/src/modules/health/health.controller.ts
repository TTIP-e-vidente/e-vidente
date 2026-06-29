import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { describePoolConfig, isRemotePostgres } from '../../config/postgresPoolConfig';
import { EXPECTED_MIGRATION_COUNT, isMigrationCountHealthy } from '../../config/migrations-meta';
import { getLastBrevoProbe } from '../email/email.brevo-probe';
import { emailConfig, isEmailDeliveryConfigured } from '../email/email.config';
import { isSupabaseEmailEdgeMode } from '../../config/supabase-email-mode';
import { getVerificationConfig } from '../email/email.verification.service';
import { getAppliedMigrationCount, getDbInfo, getSupabaseCronSnapshot } from './health.repository';

export function getHealth(_request: Request, response: Response): void {
  sendResponse(response, 200, { status: 'ok' });
}

export async function getDatabaseHealth(_request: Request, response: Response): Promise<void> {
  try {
    const info = await getDbInfo();
    const migrationCount = await getAppliedMigrationCount();
    const pool = describePoolConfig();
    sendResponse(response, 200, {
      status: 'ok',
      database: info.current_database,
      user: info.current_user,
      remote: isRemotePostgres(),
      migrations: {
        applied: migrationCount,
        expected: EXPECTED_MIGRATION_COUNT,
        healthy: isMigrationCountHealthy(migrationCount),
      },
      pool,
    });
  } catch (error) {
    sendError(response, error);
  }
}

export async function getReadiness(_request: Request, response: Response): Promise<void> {
  const checks: Record<string, { ok: boolean; detail?: string }> = {};

  try {
    const info = await getDbInfo();
    checks.database = { ok: true, detail: `${info.current_user}@${info.current_database}` };
  } catch (error) {
    checks.database = { ok: false, detail: (error as Error).message };
  }

  if (checks.database.ok) {
    try {
      const count = await getAppliedMigrationCount();
      checks.migrations = {
        ok: isMigrationCountHealthy(count),
        detail: `${count}/${EXPECTED_MIGRATION_COUNT}`,
      };
    } catch (error) {
      checks.migrations = { ok: false, detail: (error as Error).message };
    }
  }

  const deliveryConfigured = isEmailDeliveryConfigured();
  checks.email = {
    ok: !emailConfig.enabled || deliveryConfigured,
    detail: emailConfig.enabled
      ? deliveryConfigured
        ? 'brevo_configured'
        : 'brevo_missing'
      : 'disabled',
  };

  const cronOk = emailConfig.cronSecret.trim().length >= 12;
  checks.cron_secret = {
    ok: cronOk,
    detail: cronOk ? 'configured' : 'missing_or_short',
  };

  const allOk = Object.values(checks).every((check) => check.ok);
  sendResponse(response, allOk ? 200 : 503, {
    status: allOk ? 'ready' : 'not_ready',
    checks,
  });
}

export function getEmailHealth(_request: Request, response: Response): void {
  if (isSupabaseEmailEdgeMode()) {
    sendResponse(response, 200, {
      status: 'supabase_edge',
      email_enabled: emailConfig.enabled,
      delivery_configured: false,
      delivery_via: 'supabase_edge_functions',
      hints: [
        'Verify OTP y jobs de mail corren en Supabase Edge (no en Express).',
        'Chequeo: npm run check:edge:staging',
        'Deploy: npm run supabase:functions:deploy',
      ],
    });
    return;
  }
  const deliveryConfigured = isEmailDeliveryConfigured();
  const verification = getVerificationConfig();
  const brevoProbe = getLastBrevoProbe();

  sendResponse(response, 200, {
    status: deliveryConfigured && (brevoProbe?.ok !== false) ? 'ok' : 'degraded',
    email_enabled: emailConfig.enabled,
    delivery_configured: deliveryConfigured,
    brevo_api_key_present: emailConfig.brevoApiKey.length > 0,
    brevo_probe: brevoProbe,
    sender_email: emailConfig.senderEmail || null,
    sender_name: emailConfig.senderName,
    dev_code_in_logs:
      process.env.NODE_ENV === 'development' && emailConfig.enabled && !deliveryConfigured,
    verification: {
      expires_minutes: verification.expiresMinutes,
      cooldown_seconds: verification.cooldownSeconds,
      max_attempts: verification.maxAttempts
    },
    hints: deliveryConfigured
      ? brevoProbe && !brevoProbe.ok
        ? [brevoProbe.hint ?? brevoProbe.error ?? 'Brevo probe failed'].filter(Boolean)
        : []
      : [
          'Configurá BREVO_API_KEY y BREVO_SENDER_EMAIL en BACKEND/.env.staging',
          'Reiniciá el backend: npm run dev:restart',
          'El remitente debe estar Verified en Brevo',
          'En desarrollo sin Brevo, el código OTP aparece en la consola del backend (dev_code)'
        ]
  });
}

function isLocalCronUrl(url: string | null | undefined): boolean {
  if (!url) {
    return false;
  }
  return /^(https?:\/\/)?(127\.0\.0\.1|localhost)(:\d+)?(\/|$)/i.test(url.trim());
}

export async function getCronHealth(_request: Request, response: Response): Promise<void> {
  try {
    const snapshot = await getSupabaseCronSnapshot();
    const configuredUrl = snapshot.backend_base_url ?? emailConfig.publicBaseUrl;
    const localUrl = isLocalCronUrl(configuredUrl);
    const jobsOk = snapshot.jobs.length >= 4;

    sendResponse(response, 200, {
      status: !snapshot.available ? 'unavailable' : localUrl ? 'local_dev' : jobsOk ? 'ok' : 'degraded',
      supabase_pg_cron: snapshot.available,
      backend_base_url: configuredUrl || null,
      local_url_not_reachable_from_supabase: localUrl,
      node_dev_scheduler:
        !isSupabaseEmailEdgeMode() &&
        process.env.NODE_ENV === 'development' &&
        isEmailDeliveryConfigured(),
      jobs: snapshot.jobs,
      last_pg_cron_run: snapshot.last_pg_cron_run,
      recent_invocations: snapshot.recent_invocations,
      email_via_supabase_edge: isSupabaseEmailEdgeMode(),
      hints: isSupabaseEmailEdgeMode()
        ? localUrl
          ? [
              'Crons de mail van a Edge (internal-job). localhost solo afecta leaderboard opcional.',
              'npm run setup:supabase:cron',
            ]
          : !jobsOk
            ? ['npm run setup:supabase:cron']
            : []
        : localUrl
        ? [
            'Supabase no puede llamar localhost. En dev los mails los procesa npm run dev.',
            'Con deploy público: BACKEND_BASE_URL + npm run setup:supabase:cron'
          ]
        : !jobsOk
          ? ['Corré npm run setup:supabase:cron']
          : []
    });
  } catch (error) {
    sendError(response, error);
  }
}
