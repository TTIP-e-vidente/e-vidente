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
  console.log('  • Godot → Express (JWT propio) → Postgres Supabase');
  console.log('  • NO usamos Supabase Auth; el backend conecta como postgres (bypass RLS)');
  console.log('  • Migración 030 activa RLS en public (bloquea Data API anon/authenticated)\n');

  console.log('Paso 1/4 — Resolver conexión (direct → pooler fallback)');
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

  console.log('\nPaso 2/4 — Aplicar migraciones SQL (001…030, incluye RLS lockdown)');
  execSync(resolveMigrationsRunner(), {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: staging.envFile },
  });

  console.log('\nPaso 3/4 — Verificar schema, RLS y tablas críticas');
  execSync('npx ts-node scripts/verify-supabase.ts', {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: staging.envFile },
  });

  console.log('\nPaso 4/4 — Próximos pasos');
  console.log('  npm run dev:staging');
  console.log('  npm run seed:staging   (si no hay usuarios)');
  console.log('  npm run check:deploy:staging');
  console.log('\nSetup Supabase completado.');
}

main().catch((error) => {
  console.error('\nSetup Supabase falló:', error);
  process.exit(1);
});
