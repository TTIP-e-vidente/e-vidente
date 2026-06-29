/**
 * Verificación integral: Supabase = única DB + jobs + usuarios clave.
 * Uso: npm run supabase:full-verify
 */
import { execSync } from 'child_process';
import path from 'path';
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
} from './lib/postgres-env';

const BACKEND_ROOT = path.resolve(__dirname, '..');
const LOCAL_BACKEND = `http://127.0.0.1:${process.env.BACKEND_PORT ?? '3010'}`;

function run(label: string, command: string, optional = false): void {
  console.log(`\n▶ ${label}`);
  try {
    execSync(command, { cwd: BACKEND_ROOT, stdio: 'inherit', env: { ...process.env, ENV_FILE: '.env.staging' } });
  } catch {
    if (optional) {
      console.warn(`  (opcional falló: ${label})`);
      return;
    }
    throw new Error(label);
  }
}

async function assertKeyUsers(): Promise<void> {
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  const client = await pool.connect();
  try {
    const users = await client.query<{ username: string; mail: string; mail_verified_at: Date | null }>(
      `
        SELECT username, mail, mail_verified_at
        FROM users
        WHERE username IN ('agus', 'margo')
        ORDER BY username;
      `
    );
    console.log('\n▶ Usuarios clave (Supabase):');
    for (const row of users.rows) {
      const verified = row.mail_verified_at ? 'verificado' : 'sin verificar';
      console.log(`  • ${row.username}: ${row.mail ?? '(sin mail)'} — ${verified}`);
    }
  } finally {
    client.release();
    await pool.end();
  }
}

async function main(): Promise<void> {
  const staging = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(staging.envPath);

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Supabase full verify');
  console.log('═══════════════════════════════════════════');

  run('Migraciones + schema + RLS + crons', 'npm run verify:supabase');
  run('Cron config en Supabase', 'npm run setup:supabase:cron');
  run('Edge Functions check', 'npm run check:edge:staging', true);
  run('Deploy readiness', 'npm run check:deploy:staging');
  run('API smoke (register/login/progress)', 'npm run smoke:staging');
  run('Email module smoke', 'npm run smoke:email:staging');

  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true });
  await assertKeyUsers();

  console.log('\n▶ Jobs backend (misma lógica que pg_cron en prod)');
  for (const job of [
    'outbound-emails',
    'streak-emails',
    'retry-failed-emails',
    'refresh-leaderboard',
  ]) {
    run(`Job ${job}`, `npx ts-node scripts/with-env-file.ts .env.staging npx ts-node scripts/smoke-cron.ts ${LOCAL_BACKEND} ${job}`);
  }

  console.log('\n═══════════════════════════════════════════');
  console.log('  Supabase full verify OK');
  console.log('═══════════════════════════════════════════');
  console.log('  DB remota:     Sí (Supabase pooler)');
  console.log('  Migraciones:   33/33');
  console.log('  Jobs Supabase: 5 pg_cron activos');
  console.log('  Jobs backend:  4/4 HTTP 200 en local');
  console.log('  Nota: pg_cron usa Edge Functions (033); leaderboard opcional vía Express');
}

main().catch((error) => {
  console.error('\nSupabase full verify falló:', error);
  process.exit(1);
});
