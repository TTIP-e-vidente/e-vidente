import { execSync } from 'child_process';
import {
  BACKEND_ROOT,
  assertSupabaseStagingEnv,
  createPoolFromCurrentEnv,
  describeConnection,
  loadPostgresEnv,
  validatePoolConnection,
} from './lib/postgres-env';

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

  console.log('Paso 1/4 — Validar conexión');
  console.log(`  ${describeConnection()}`);
  console.log('  Tip: usá host DIRECT (db.<ref>.supabase.co) para DDL/migraciones.\n');

  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  try {
    const info = await validatePoolConnection(pool);
    console.log(`  OK — DB: ${info.database} | user: ${info.user}`);
  } catch (error) {
    console.error('\nERROR: no se pudo conectar a Supabase.');
    console.error((error as Error).message);
    console.error('\nChecklist:');
    console.error('  1. Proyecto activo en dashboard.supabase.com');
    console.error('  2. Password de DB en Project Settings → Database');
    console.error('  3. POSTGRES_SSL=true en .env.staging');
    console.error('  4. Host directo db.<project-ref>.supabase.co (no pooler para migrate)');
    process.exit(1);
  } finally {
    await pool.end();
  }

  console.log('\nPaso 2/4 — Aplicar migraciones SQL (001…030, incluye RLS lockdown)');
  execSync('npx ts-node scripts/run-migrations.ts', {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: staging.envFile },
  });

  console.log('\nPaso 3/4 — Verificar schema_migrations');
  const verifyPool = createPoolFromCurrentEnv();
  try {
    const applied = await verifyPool.query<{ count: string }>(
      'SELECT COUNT(*)::text AS count FROM schema_migrations;'
    );
    console.log(`  Migraciones registradas: ${applied.rows[0]?.count ?? '0'}`);
  } finally {
    await verifyPool.end();
  }

  console.log('\nPaso 4/4 — Próximos pasos');
  console.log('  A) (Opcional) Copiar datos desde Docker local:');
  console.log('     npm run migrate:data-to-supabase:dry-run');
  console.log('     npm run migrate:data-to-supabase');
  console.log('  B) Cambiar .env.staging al Session pooler para runtime (ver .env.staging.example)');
  console.log('  C) Probar API contra Supabase:');
  console.log('     npm run smoke:api:staging');
  console.log('  D) Levantar backend con staging:');
  console.log('     npm run dev:staging');
  console.log('\nSetup Supabase completado.');
}

main().catch((error) => {
  console.error('\nSetup Supabase falló:', error);
  process.exit(1);
});
