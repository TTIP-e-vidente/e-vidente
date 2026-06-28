/**
 * Punto de entrada único para integrar Supabase.
 *
 * Uso:
 *   npm run supabase:bootstrap              # preview
 *   npm run supabase:bootstrap -- --apply   # schema + verify
 *   npm run supabase:bootstrap -- --apply --with-data --with-smoke --seed
 */
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import {
  BACKEND_ROOT,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
} from './lib/postgres-env';
import {
  hasFailedChecks,
  printEnvChecks,
  validateSupabaseEnvFields,
} from './lib/supabase-env';

const STAGING_ENV = '.env.staging';

function run(command: string, label: string): void {
  console.log(`\n▶ ${label}`);
  execSync(command, {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: STAGING_ENV },
  });
}

async function countUsers(): Promise<number> {
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 10_000 });
  try {
    const result = await pool.query<{ count: string }>('SELECT COUNT(*)::text AS count FROM users;');
    return Number.parseInt(result.rows[0]?.count ?? '0', 10);
  } finally {
    await pool.end();
  }
}

function printNextSteps(): void {
  console.log('\n═══════════════════════════════════════════');
  console.log('  Próximos pasos');
  console.log('═══════════════════════════════════════════');
  console.log('  1. (Opcional) Cambiar .env.staging al Session pooler para runtime');
  console.log('  2. npm run check:deploy:staging');
  console.log('  3. npm run dev:staging');
  console.log('  4. Deploy: configurá BACKEND_BASE_URL + secrets en GitHub');
  console.log('     → Actions → Email cron jobs (o npm run smoke:cron:staging)');
  console.log('  Guía: docs/SUPABASE_QUICKSTART.md');
}

async function main(): Promise<void> {
  const apply = process.argv.includes('--apply');
  const withData = process.argv.includes('--with-data');
  const withSmoke = process.argv.includes('--with-smoke');
  const seed = process.argv.includes('--seed');
  const skipSetup = process.argv.includes('--skip-setup');

  const stagingPath = path.resolve(BACKEND_ROOT, STAGING_ENV);
  if (!fs.existsSync(stagingPath)) {
    console.error(`No existe ${STAGING_ENV}. Corré primero: npm run supabase:init`);
    process.exit(1);
  }

  loadPostgresEnv('staging');

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Bootstrap Supabase');
  console.log('═══════════════════════════════════════════');
  console.log(`Modo: ${apply ? 'APPLY' : 'PREVIEW'}\n`);

  const envChecks = validateSupabaseEnvFields({
    envPath: stagingPath,
    requireBrevo: false,
  });
  console.log('Preflight env:');
  printEnvChecks(envChecks);
  if (hasFailedChecks(envChecks)) {
    console.error('\nCompletá .env.staging antes de continuar.');
    process.exit(1);
  }

  if (!apply) {
    console.log('\nPreview — para aplicar: npm run supabase:bootstrap:apply');
    console.log('            con datos: npm run supabase:bootstrap:full');
    if (withData) {
      run('npm run migrate:data-to-supabase:dry-run', 'Preview datos local → Supabase');
    }
    printNextSteps();
    return;
  }

  if (!skipSetup) {
    run('npm run setup:supabase', 'Schema + migraciones + verify');
  } else {
    run('npm run verify:supabase', 'Verificar Supabase');
  }

  if (withData) {
    run('npm run migrate:data-to-supabase', 'Copiar datos local → Supabase');
    run('npm run verify:supabase:compare-local', 'Verificar conteo vs local');
  }

  const users = await countUsers();
  if (users === 0 && seed) {
    run('npm run seed:staging', 'Seed usuarios demo (agus/margo)');
  } else if (users === 0) {
    console.log('\n▶ Sin usuarios en Supabase. Agregá --seed o npm run seed:staging');
  } else {
    console.log(`\n▶ Usuarios en Supabase: ${users}`);
  }

  run('npm run check:deploy:staging', 'Deploy readiness');

  if (withSmoke) {
    run('npm run smoke:staging', 'Smoke API');
  }

  printNextSteps();
  console.log('\nBootstrap Supabase completado.');
}

main().catch((error) => {
  console.error('\nBootstrap Supabase falló:', error);
  process.exit(1);
});
