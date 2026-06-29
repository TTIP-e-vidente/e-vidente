/**
 * Configura URL + secret en Supabase y (re)programa pg_cron → POST /internal/jobs/*
 *
 * Uso:
 *   npm run setup:supabase:cron
 *
 * Variables (.env.staging):
 *   BACKEND_BASE_URL  — URL pública del backend (Render, etc.). localhost no funciona desde Supabase.
 *   EMAIL_CRON_SECRET — mismo valor que usa el backend (header X-Job-Secret)
 */
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  describeConnection,
  loadBackendEnv,
} from './lib/postgres-env';
import { resolveSupabaseFunctionsUrl } from './lib/supabase-functions-env';

const LOCALHOST_PATTERN = /^(https?:\/\/)?(127\.0\.0\.1|localhost)(:\d+)?(\/|$)/i;

function resolveBackendBaseUrl(): string {
  const explicit = (process.env.BACKEND_BASE_URL ?? process.env.PUBLIC_API_URL ?? '').trim();
  if (explicit.length > 0) {
    return explicit.replace(/\/+$/, '');
  }
  const port = process.env.BACKEND_PORT ?? '3010';
  return `http://127.0.0.1:${port}`;
}

function resolveCronSecret(): string {
  return (process.env.EMAIL_CRON_SECRET ?? '').trim();
}

async function upsertSetting(
  client: import('pg').PoolClient,
  key: string,
  value: string
): Promise<void> {
  await client.query(
    `
      INSERT INTO private.internal_cron_settings (key, value, updated_at)
      VALUES ($1, $2, now())
      ON CONFLICT (key) DO UPDATE
      SET value = EXCLUDED.value, updated_at = now();
    `,
    [key, value]
  );
}

async function main(): Promise<void> {
  const loaded = loadBackendEnv();
  assertSupabaseStagingEnv(loaded.envPath);

  const baseUrl = resolveBackendBaseUrl();
  const cronSecret = resolveCronSecret();

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Supabase cron jobs');
  console.log('═══════════════════════════════════════════\n');

  if (cronSecret.length < 12) {
    console.error('ERROR: EMAIL_CRON_SECRET vacío o corto en .env.staging (mín. 12 caracteres).');
    process.exit(1);
  }

  if (LOCALHOST_PATTERN.test(baseUrl)) {
    console.warn('AVISO: BACKEND_BASE_URL es local (%s).', baseUrl);
    console.warn('  Supabase pg_cron NO puede llamar localhost.');
    console.warn('  Los jobs quedan programados pero se omiten hasta tener URL pública (Render + BACKEND_BASE_URL).\n');
  } else {
    console.log(`Backend objetivo: ${baseUrl}`);
  }

  await connectSupabase({ envPath: loaded.envPath, persistToEnvFile: true });
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 20000 });
  const client = await pool.connect();

  try {
    const ext = await client.query<{ extname: string }>(
      `SELECT extname FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net');`
    );
    const names = new Set(ext.rows.map((row) => row.extname));
    if (!names.has('pg_cron') || !names.has('pg_net')) {
      console.error(
        'ERROR: faltan extensiones pg_cron/pg_net. Corré primero: npm run setup:supabase (migración 031).'
      );
      process.exit(1);
    }

    await upsertSetting(client, 'backend_base_url', baseUrl);
    await upsertSetting(client, 'email_cron_secret', cronSecret);

    const functionsUrl = resolveSupabaseFunctionsUrl();
    const anonKey = (process.env.SUPABASE_ANON_KEY ?? '').trim();
    if (functionsUrl && anonKey) {
      await upsertSetting(client, 'supabase_functions_url', functionsUrl);
      await upsertSetting(client, 'supabase_anon_key', anonKey);
      console.log(`Edge Functions cron: ${functionsUrl}/internal-job`);
    } else {
      console.warn(
        'AVISO: Falta SUPABASE_ANON_KEY — pg_cron usará fallback Express (BACKEND_BASE_URL).'
      );
    }

    const refresh = await client.query<{ refresh_evidente_cron_jobs: unknown }>(
      `SELECT private.refresh_evidente_cron_jobs() AS refresh_evidente_cron_jobs;`
    );
    const payload = refresh.rows[0]?.refresh_evidente_cron_jobs as
      | { ok?: boolean; scheduled?: number; reason?: string }
      | undefined;

    if (!payload?.ok) {
      console.error('ERROR al programar crons:', payload?.reason ?? 'unknown');
      process.exit(1);
    }

    console.log(`Crons programados: ${payload.scheduled ?? 0} (${describeConnection()})`);

    const jobs = await client.query<{ jobname: string; schedule: string; active: boolean }>(
      `
        SELECT jobname, schedule, active
        FROM cron.job
        WHERE jobname LIKE 'evidente-%'
        ORDER BY jobname;
      `
    );

    console.log('\nJobs en Supabase (pg_cron):');
    for (const job of jobs.rows) {
      console.log(`  • ${job.jobname}  ${job.schedule}  active=${job.active}`);
    }

    console.log('\nHorarios UTC (ART ≈ UTC−3):');
    console.log('  evidente-streak-emails      → 22:00 UTC (19:00 ART)');
    console.log('  evidente-retry-failed-am    → 11:00 UTC (08:00 ART)');
    console.log('  evidente-retry-failed-pm    → 23:00 UTC (20:00 ART)');
    console.log('  evidente-refresh-leaderboard → cada hora :15 UTC');

    console.log('\nSetup cron Supabase OK.');
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error('\nSetup cron Supabase falló:', error);
  process.exit(1);
});
