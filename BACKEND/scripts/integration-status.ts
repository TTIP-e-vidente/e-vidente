/**
 * Panel de integración: DB, Godot config, Edge Functions, Express, crons.
 * Uso: npm run integrate:status
 */
import fs from 'fs';
import path from 'path';
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
} from './lib/postgres-env';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import { EXPECTED_MIGRATION_COUNT } from './lib/public-tables';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';
import { fetchRemoteHealth, isLocalBackendUrl, resolvePublicBackendUrl } from './lib/cloud-backend-url';
import { isSupabaseEmailEdgeMode, isSupabaseApiEdgeMode, canReachSupabaseEmailEdge } from '../src/config/supabase-email-mode';
import { isEmailDeliveryConfigured } from '../src/modules/email/email.config';

const BACKEND_ROOT = path.resolve(__dirname, '..');
const GODOT_CONFIG = path.resolve(BACKEND_ROOT, '../juego/config/backend.local.json');
const KEYS_LOCAL = path.resolve(BACKEND_ROOT, '.env.supabase-keys.local');

type Row = { label: string; ok: boolean; detail: string };

const strict =
  process.argv.includes('--strict') || process.env.VERIFY_INTEGRATION_STRICT === '1';

function row(label: string, ok: boolean, detail: string): Row {
  return { label, ok, detail };
}

async function checkEdgeHealth(): Promise<{ row: Row; deliveryConfigured: boolean }> {
  if (!canUseSupabaseEmailFunctions()) {
    return {
      row: row('Edge Functions', false, 'Falta SUPABASE_PUBLISHABLE_KEY en .env.staging'),
      deliveryConfigured: false,
    };
  }
  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  try {
    const response = await fetch(`${baseUrl}/verify-email-health`, {
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
    });
    if (response.status === 404) {
      return {
        row: row('Edge Functions', false, 'No desplegadas — npm run supabase:functions:deploy'),
        deliveryConfigured: false,
      };
    }
    if (!response.ok) {
      return {
        row: row('Edge Functions', false, `verify-email-health HTTP ${response.status}`),
        deliveryConfigured: false,
      };
    }
    const body = (await response.json()) as {
      delivery_configured?: boolean;
      brevo_probe?: { ok?: boolean; hint?: string; error?: string };
    };
    const authHealthResponse = await fetch(`${baseUrl}/auth-health`, {
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
    });
    const authHealthBody = (await authHealthResponse.json().catch(() => ({}))) as {
      status?: string;
      migrations?: { applied?: number; expected?: number; healthy?: boolean };
    };
    const authOk =
      authHealthResponse.ok &&
      authHealthBody.status === 'ok' &&
      authHealthBody.migrations?.healthy === true &&
      authHealthBody.migrations?.expected === EXPECTED_MIGRATION_COUNT;
    const deliveryConfigured = body.delivery_configured === true;
    const probeHint = body.brevo_probe?.hint ?? body.brevo_probe?.error;
    const brevo = deliveryConfigured
      ? 'Brevo OK'
      : probeHint
        ? `Brevo: ${probeHint.slice(0, 120)}`
        : 'Brevo no configurado — npm run supabase:functions:secrets';
    const migDetail = authHealthBody.migrations
      ? `migraciones Edge ${authHealthBody.migrations.applied}/${authHealthBody.migrations.expected}`
      : 'auth-health sin migraciones';
    const gameApi = authOk
      ? `auth+game API OK · ${migDetail}`
      : `falta deploy o migraciones desalineadas (${migDetail})`;
    return {
      row: row('Edge Functions', authOk && deliveryConfigured, `${baseUrl} · ${brevo} · ${gameApi}`),
      deliveryConfigured,
    };
  } catch (error) {
    return {
      row: row('Edge Functions', false, error instanceof Error ? error.message : String(error)),
      deliveryConfigured: false,
    };
  }
}

async function checkExpress(): Promise<Row> {
  if (isSupabaseApiEdgeMode()) {
    return row('Express API', true, 'No requerido (api_mode=supabase_edge)');
  }
  const publicUrl = resolvePublicBackendUrl();
  if (!isLocalBackendUrl(publicUrl)) {
    const health = await fetchRemoteHealth(publicUrl);
    return row(
      'Express API',
      health.ok,
      health.ok ? `${publicUrl} (cloud)` : `${publicUrl} no responde /health/ready`,
    );
  }
  const port = process.env.BACKEND_PORT ?? '3010';
  const local = `http://127.0.0.1:${port}`;
  try {
    const response = await fetch(`${local}/health`, { signal: AbortSignal.timeout(3000) });
    return row(
      'Express API',
      response.ok,
      response.ok ? `${local} (local — login/progreso)` : `HTTP ${response.status}`,
    );
  } catch {
    return row(
      'Express API',
      false,
      `${local} apagado — npm run dev (solo login/progreso; verify va por Supabase)`,
    );
  }
}

async function main(): Promise<void> {
  loadStagingWithKeys();
  const envPath = path.resolve(BACKEND_ROOT, process.env.ENV_FILE?.trim() || '.env.staging');
  assertSupabaseStagingEnv(envPath);

  const rows: Row[] = [];

  rows.push(
    fs.existsSync(KEYS_LOCAL)
      ? row('Keys locales', true, '.env.supabase-keys.local presente')
      : row('Keys locales', false, 'Creá .env.supabase-keys.local → npm run configure:supabase-keys'),
  );

  rows.push(
    canUseSupabaseEmailFunctions()
      ? row('SUPABASE_ANON_KEY', true, 'Configurada en .env.staging')
      : row('SUPABASE_ANON_KEY', false, 'npm run configure:supabase-keys'),
  );

  if (fs.existsSync(GODOT_CONFIG)) {
    const godot = JSON.parse(fs.readFileSync(GODOT_CONFIG, 'utf8')) as Record<string, unknown>;
    const apiMode = str(godot.api_mode);
    const edgeMode = apiMode === 'supabase_edge';
    const baseUrl = str(godot.base_url);
    const functionsUrl = str(godot.supabase_functions_url);
    const anonKey = str(godot.supabase_anon_key);
    const viaSupabase = bool(godot.email_via_supabase) || str(godot.db) === 'supabase';
    const noLocalhost =
      !isLocalBackendUrl(baseUrl) && !isLocalBackendUrl(functionsUrl) && !baseUrl.includes(':3000');
    const edgeUrlsOk = !edgeMode || (functionsUrl.includes('/functions/v1') && noLocalhost);
    const anonOk = anonKey.startsWith('sb_publishable_') || anonKey.length >= 20;
    const configOk =
      baseUrl.length > 0 && noLocalhost && canReachSupabaseEmailEdge() && edgeUrlsOk && anonOk;
    rows.push(
      row(
        'Godot config',
        viaSupabase && configOk,
        `api=${apiMode || 'local'} · base=${baseUrl} · edge=${edgeMode ? 'sí' : 'no'}`,
      ),
    );
  } else {
    rows.push(row('Godot config', false, 'Falta juego/config/backend.local.json — npm run sync:godot-config:staging'));
  }

  await connectSupabase({ envPath, persistToEnvFile: true, silent: true });
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  const client = await pool.connect();
  try {
    const mig = await client.query<{ count: string }>(
      'SELECT COUNT(*)::text AS count FROM schema_migrations;',
    );
    const count = Number.parseInt(mig.rows[0]?.count ?? '0', 10);
    rows.push(
      row('Migraciones', count >= EXPECTED_MIGRATION_COUNT, `${count}/${EXPECTED_MIGRATION_COUNT}`),
    );

    const cronSettings = await client.query<{ key: string; value: string }>(
      `SELECT key, value FROM private.internal_cron_settings WHERE key IN (
        'supabase_functions_url', 'supabase_anon_key', 'email_cron_secret'
      );`,
    );
    const map = new Map(cronSettings.rows.map((r) => [r.key, r.value]));
    const cronOk =
      Boolean(map.get('supabase_functions_url')?.trim()) &&
      Boolean(map.get('supabase_anon_key')?.trim()) &&
      Boolean(map.get('email_cron_secret')?.trim());
    rows.push(
      row(
        'pg_cron → Edge',
        cronOk,
        cronOk ? 'Crons apuntan a Edge Functions' : 'npm run setup:supabase:cron',
      ),
    );

    const users = await client.query<{ c: string }>('SELECT COUNT(*)::text AS c FROM users;');
    rows.push(row('Usuarios DB', true, `${users.rows[0]?.c ?? 0} en Supabase`));

    const cronLog = await client.query<{
      job_path: string;
      skipped_reason: string | null;
      created_at: Date;
    }>(
      `SELECT job_path, skipped_reason, created_at
       FROM private.cron_invocation_log
       ORDER BY created_at DESC
       LIMIT 8`,
    );
    const cronRows = cronLog.rows;
    const cronInvocationsOk =
      cronRows.length === 0 || cronRows.some((entry) => !entry.skipped_reason);
    const lastCron = cronRows[0];
    const cronDetail =
      lastCron == null
        ? 'sin registros — npm run setup:supabase:cron'
        : `último ${lastCron.job_path} · ${
            lastCron.skipped_reason
              ? `SKIP ${lastCron.skipped_reason}`
              : 'enviado a Edge'
          }`;
    rows.push(row('Crons recientes', cronInvocationsOk, cronDetail));

    const failedMails = await client.query<{ c: string }>(
      `SELECT COUNT(*)::text AS c FROM email_deliveries
       WHERE status = 'failed'
         AND COALESCE(failed_at, created_at) >= now() - interval '24 hours'`,
    );
    const failedCount = Number.parseInt(failedMails.rows[0]?.c ?? '0', 10);
    rows.push(
      row(
        'Mails failed 24h',
        failedCount === 0,
        failedCount === 0 ? 'ninguno' : `${failedCount} fallido(s) — revisá Brevo / verify-email-health`,
      ),
    );

    const lbMeta = await client.query<{
      scope: string;
      error_message: string | null;
      last_refreshed_at: Date | null;
    }>(
      `SELECT scope, error_message, last_refreshed_at
       FROM leaderboard_meta
       ORDER BY scope`,
    );
    const lbRows = lbMeta.rows;
    const lbErrors = lbRows.filter((entry) => entry.error_message);
    const lbOk = lbRows.length > 0 && lbErrors.length === 0;
    const lbDetail =
      lbRows.length === 0
        ? 'sin filas — npm run smoke:leaderboard-edge'
        : lbErrors.length > 0
          ? `error en: ${lbErrors.map((entry) => entry.scope).join(', ')}`
          : `${lbRows.length} scope(s) OK`;
    rows.push(row('Leaderboard meta', lbOk, lbDetail));
  } finally {
    client.release();
    await pool.end();
  }

  rows.push(
    row(
      'Mails en Express',
      isSupabaseEmailEdgeMode(),
      isSupabaseEmailEdgeMode()
        ? 'Desactivado (correcto) — solo Edge + pg_cron'
        : 'Activo (Postgres local)',
    ),
  );

  const edgeHealth = await checkEdgeHealth();

  const brevoConfigured = edgeHealth.deliveryConfigured;
  const brevoDetail = isSupabaseEmailEdgeMode()
    ? brevoConfigured
      ? 'Brevo activo en Edge'
      : 'Pendiente — npm run supabase:functions:secrets (mail OTP no enviará)'
    : isEmailDeliveryConfigured()
      ? 'OK en .env local'
      : 'Falta BREVO_*';

  rows.push(
    row(
      'Brevo (Edge secrets)',
      !isSupabaseEmailEdgeMode() || brevoConfigured || !strict,
      brevoDetail,
    ),
  );

  rows.push(edgeHealth.row);
  rows.push(await checkExpress());

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Integración Supabase + Godot');
  console.log('═══════════════════════════════════════════\n');

  let failed = 0;
  for (const r of rows) {
    console.log(`  ${r.ok ? '✓' : '✗'} ${r.label.padEnd(18)} ${r.detail}`);
    if (!r.ok) {
      failed += 1;
    }
  }

  console.log('\n───────────────────────────────────────────');
  console.log('  Flujo objetivo:');
  console.log('    Login/progreso → Supabase Edge (api_mode=supabase_edge)');
  console.log('    Verify OTP     → Supabase Edge Functions');
  console.log('    Jobs mail      → pg_cron → Edge internal-job');
  console.log('───────────────────────────────────────────');

  if (failed > 0) {
    console.log(`\n${failed} chequeo(s) pendientes → npm run integrate:staging\n`);
    process.exit(1);
  }
  if (strict) {
    console.log('\nModo strict: corré también npm run verify:integration:strict tras configurar Brevo.\n');
  }
  console.log('\nIntegración OK.\n');
}

function str(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function bool(value: unknown): boolean {
  return value === true;
}

main().catch((error) => {
  console.error('\nintegrate:status falló:', error);
  process.exit(1);
});
