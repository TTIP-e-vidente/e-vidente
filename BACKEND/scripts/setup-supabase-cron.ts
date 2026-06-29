/**
 * Configura pg_cron en Supabase → Edge `internal-job`.
 *
 * Uso:
 *   npm run setup:supabase:cron
 *
 * Variables (.env.staging):
 *   EMAIL_CRON_SECRET — mismo valor que secrets Edge (header X-Job-Secret)
 *   SUPABASE_ANON_KEY / SUPABASE_PUBLISHABLE_KEY — para que pg_cron autorice Edge
 */
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  describeConnection,
  loadBackendEnv,
} from './lib/postgres-env';
import { resolveSupabaseClientApiKey, resolveSupabaseFunctionsUrl } from './lib/supabase-functions-env';

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

  const cronSecret = resolveCronSecret();

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Supabase cron jobs');
  console.log('═══════════════════════════════════════════\n');

  if (cronSecret.length < 12) {
    console.error('ERROR: EMAIL_CRON_SECRET vacío o corto en .env.staging (mín. 12 caracteres).');
    process.exit(1);
  }

  const functionsUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  if (!functionsUrl || !anonKey) {
    console.error('ERROR: Falta SUPABASE_ANON_KEY o SUPABASE_PROJECT_REF — pg_cron requiere Edge Functions.');
    console.error('  Corré: npm run configure:supabase-keys');
    process.exit(1);
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

    await upsertSetting(client, 'email_cron_secret', cronSecret);
    await upsertSetting(client, 'supabase_functions_url', functionsUrl);
    await upsertSetting(client, 'supabase_anon_key', anonKey);
    console.log(`Edge Functions cron: ${functionsUrl}/internal-job`);

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

    console.log('\nHorarios UTC (ART ≈ UTC−3, ver EMAIL_TIMEZONE en Edge):');
    console.log('  evidente-streak-at-risk     → 21:00 UTC (18:00 ART) — aviso racha en riesgo');
    console.log('  evidente-streak-lost        → 03:00 UTC (00:00 ART) — racha perdida + reset DB');
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
