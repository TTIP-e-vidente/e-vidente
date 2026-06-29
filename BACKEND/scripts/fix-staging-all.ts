/**
 * Deja staging listo de punta a punta (Supabase Edge + pg_cron).
 *
 * Uso:
 *   npm run staging:fix-all
 */
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import {
  BACKEND_ROOT,
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
} from './lib/postgres-env';

const STAGING_ENV = '.env.staging';
const KEYS_LOCAL = path.resolve(BACKEND_ROOT, '.env.supabase-keys.local');

function run(label: string, command: string, optional = false): void {
  console.log(`\n▶ ${label}`);
  try {
    execSync(command, {
      cwd: BACKEND_ROOT,
      stdio: 'inherit',
      env: { ...process.env, ENV_FILE: STAGING_ENV },
    });
  } catch (error) {
    if (optional) {
      console.warn(`  (opcional falló: ${label})`);
      return;
    }
    throw error;
  }
}

async function assertUsersOk(): Promise<void> {
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  const client = await pool.connect();
  try {
    const users = await client.query<{
      username: string;
      mail: string | null;
      mail_verified_at: Date | null;
    }>(
      `
        SELECT username, mail, mail_verified_at
        FROM users
        WHERE username IN ('agus', 'margo')
        ORDER BY username;
      `
    );
    console.log('\n▶ Cuentas staging:');
    for (const row of users.rows) {
      const st = row.mail_verified_at ? 'mail verificado' : 'mail sin verificar';
      console.log(`  • ${row.username}: ${row.mail ?? '(sin mail)'} — ${st}`);
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
  console.log('  E-VIDENTE — Arreglar staging (Supabase Edge)');
  console.log('═══════════════════════════════════════════');

  if (!fs.existsSync(KEYS_LOCAL)) {
    console.error('\n✗ Falta BACKEND/.env.supabase-keys.local');
    console.error('  npm run configure:supabase-keys\n');
    process.exit(1);
  }

  run('Sync secrets .env → .env.staging', 'npx ts-node scripts/sync-staging-secrets.ts');
  run('Supabase keys → .env.staging', 'npx ts-node scripts/configure-supabase-api-keys.ts');

  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true });

  run('Migraciones SQL', 'npx ts-node scripts/run-migrations.ts');
  run('Edge Functions deploy', 'npx ts-node scripts/setup-supabase-functions.ts');
  run('pg_cron → Edge', 'npx ts-node scripts/setup-supabase-cron.ts');
  run('Sync Godot', 'npx ts-node scripts/sync-godot-backend-config.ts');
  run('Reparar mails verificados', 'npx ts-node scripts/repair-mail-verification.ts -- --apply', true);
  run('Verificar schema + RLS + crons', 'npm run verify:supabase');
  run('Verificación integral', 'npm run verify:integration:full', true);

  await assertUsersOk();

  console.log('\n═══════════════════════════════════════════');
  console.log('  staging:fix-all completado');
  console.log('  Godot → F5 (sin npm run dev)');
  console.log('═══════════════════════════════════════════');
}

main().catch((error) => {
  console.error('\nstaging:fix-all falló:', error);
  process.exit(1);
});
