/**
 * Deja la integración staging lista (keys + migrate + cron + godot + status).
 * Uso: npm run integrate:staging
 */
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { BACKEND_ROOT } from './lib/postgres-env';

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
  } catch {
    if (optional) {
      console.warn(`  (opcional: ${label})`);
      return;
    }
    throw new Error(label);
  }
}

function main(): void {
  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Integrar staging');
  console.log('═══════════════════════════════════════════');

  if (fs.existsSync(KEYS_LOCAL)) {
    run('Supabase API keys → .env.staging', 'npx ts-node scripts/configure-supabase-api-keys.ts');
  } else {
    console.error('\n✗ Falta BACKEND/.env.supabase-keys.local');
    console.error('  1. Copiá docs/env.supabase-keys.local.example');
    console.error('  2. Pegá SUPABASE_ANON_KEY del dashboard (Settings → API)');
    console.error('  3. Volvé a correr: npm run integrate:staging\n');
    process.exit(1);
  }

  run('CLI acceso proyecto', 'npx ts-node scripts/verify-supabase-cli-access.ts');

  run('Migraciones', 'npx ts-node scripts/run-migrations.ts');
  run('Edge Functions deploy', 'npx ts-node scripts/setup-supabase-functions.ts', true);
  run('pg_cron → Edge', 'npx ts-node scripts/setup-supabase-cron.ts');
  run('Sync Godot', 'npx ts-node scripts/sync-godot-backend-config.ts');
  run('Usuarios Supabase', 'npx ts-node scripts/query-supabase-users.ts');
  run('Panel integración', 'npx ts-node scripts/integration-status.ts');
}

main();
