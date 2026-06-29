import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import {
  BACKEND_ROOT,
  assertSupabaseStagingEnv,
  connectSupabase,
  describeConnection,
  loadPostgresEnv,
} from './lib/postgres-env';

function resolveMigrationsRunner(): string {
  const compiled = `${BACKEND_ROOT}/dist/scripts/run-migrations.js`;
  if (fs.existsSync(compiled)) {
    return 'node dist/scripts/run-migrations.js';
  }
  return 'npx ts-node scripts/run-migrations.ts';
}

async function main(): Promise<void> {
  const staging = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(staging.envPath);

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Setup Supabase');
  console.log('═══════════════════════════════════════════');
  console.log('\nArquitectura:');
  console.log('  • Godot → Supabase Edge Functions → Postgres + Storage');
  console.log('  • Crons: pg_cron → internal-job (Edge) → Brevo');
  console.log('  • Express solo legacy/tests — ver EXPRESS_LEGACY.md\n');

  console.log('Paso 1/5 — Resolver conexión (direct → pooler fallback)');
  console.log(`  Config: ${describeConnection()}\n`);

  try {
    const info = await connectSupabase({
      envPath: staging.envPath,
      persistToEnvFile: true,
    });
    console.log(`\n  Conectado: ${info.user}@${info.database}`);
    console.log(`  Activo: ${describeConnection()}`);
  } catch (error) {
    console.error('\nERROR: no se pudo conectar a Supabase.');
    console.error((error as Error).message);
    console.error('\nProbá: npm run supabase:diagnose');
    process.exit(1);
  }

  console.log('\nPaso 2/5 — Aplicar migraciones SQL (001…031, incluye RLS + pg_cron)');
  execSync(resolveMigrationsRunner(), {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: staging.envFile },
  });

  console.log('\nPaso 3/5 — Verificar schema, RLS y tablas críticas');
  execSync('npx ts-node scripts/verify-supabase.ts', {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: staging.envFile },
  });

  console.log('\nPaso 4/5 — Programar jobs en Supabase (pg_cron → Edge)');
  try {
    execSync('npm run setup:supabase:cron', {
      cwd: BACKEND_ROOT,
      stdio: 'inherit',
      env: { ...process.env, ENV_FILE: staging.envFile },
    });
  } catch {
    console.warn('\nAVISO: setup cron falló. Reintentá: npm run setup:supabase:cron');
  }

  console.log('\nPaso 5/5 — Próximos pasos');
  console.log('  npm run integrate:staging');
  console.log('  npm run seed:staging   (si no hay usuarios)');
  console.log('  npm run setup:supabase:cron  (si cambiás EMAIL_CRON_SECRET o Edge URL)');
  console.log('  npm run verify:integration:full');
  console.log('\nSetup Supabase completado.');
}

main().catch((error) => {
  console.error('\nSetup Supabase falló:', error);
  process.exit(1);
});
