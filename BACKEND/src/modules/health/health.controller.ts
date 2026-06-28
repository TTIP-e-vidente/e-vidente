import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { describePoolConfig, isRemotePostgres } from '../../config/postgresPoolConfig';
import { EXPECTED_MIGRATION_COUNT, isMigrationCountHealthy } from '../../config/migrations-meta';
import { emailConfig, isEmailDeliveryConfigured } from '../email/email.config';
import { getVerificationConfig } from '../email/email.verification.service';
import { getAppliedMigrationCount, getDbInfo } from './health.repository';

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
  const deliveryConfigured = isEmailDeliveryConfigured();
  const verification = getVerificationConfig();

  sendResponse(response, 200, {
    status: deliveryConfigured ? 'ok' : 'degraded',
    email_enabled: emailConfig.enabled,
    delivery_configured: deliveryConfigured,
    brevo_api_key_present: emailConfig.brevoApiKey.length > 0,
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
      ? []
      : [
          'Configurá BREVO_API_KEY y BREVO_SENDER_EMAIL en BACKEND/.env',
          'El remitente debe estar Verified en Brevo',
          'En desarrollo sin Brevo, el código OTP aparece en la consola del backend (dev_code)'
        ]
  });
}
