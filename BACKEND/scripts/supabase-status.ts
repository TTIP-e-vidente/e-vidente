/**
 * Estado del stack Supabase (env + DB + datos).
 * Uso: npm run supabase:status
 */
import {
  BACKEND_ROOT,
  connectSupabase,
  createPoolFromCurrentEnv,
  describeConnection,
  loadPostgresEnv,
} from './lib/postgres-env';
import { EXPECTED_MIGRATION_COUNT } from './lib/public-tables';
import {
  hasFailedChecks,
  printEnvChecks,
  validateSupabaseEnvFields,
} from './lib/supabase-env';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';

async function main(): Promise<void> {
  const staging = loadPostgresEnv('staging');

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Estado Supabase');
  console.log('═══════════════════════════════════════════\n');

  const envChecks = validateSupabaseEnvFields({ envPath: staging.envPath, requireBrevo: false });
  printEnvChecks(envChecks);

  if (!isRemotePostgres()) {
    console.error('\nPOSTGRES_SSL no está activo en .env.staging');
    process.exit(1);
  }

  if (hasFailedChecks(envChecks)) {
    process.exit(1);
  }

  console.log('\nConexión:');
  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true, silent: true });
  console.log(`  ${describeConnection()}`);

  const pool = createPoolFromCurrentEnv();
  try {
    const migrations = await pool.query<{ count: string }>(
      'SELECT COUNT(*)::text AS count FROM schema_migrations;'
    );
    const users = await pool.query<{ count: string }>('SELECT COUNT(*)::text AS count FROM users;');
    const migCount = Number.parseInt(migrations.rows[0]?.count ?? '0', 10);
    const userCount = Number.parseInt(users.rows[0]?.count ?? '0', 10);

    console.log('\nBase de datos:');
    console.log(`  Migraciones: ${migCount}/${EXPECTED_MIGRATION_COUNT} ${migCount >= EXPECTED_MIGRATION_COUNT ? 'OK' : 'PENDIENTE'}`);
    console.log(`  Usuarios: ${userCount}`);

    console.log('\nRuntime local:');
    console.log('  npm run dev');

    console.log('\nDeploy cloud (Express + Supabase Postgres):');
    console.log('  1. Render/Railway/Docker → npm run start:prod');
    console.log('  2. npm run setup:supabase:cron (pg_cron → Edge)');
    console.log('  Guía: docs/SUPABASE_QUICKSTART.md');
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error('\n', (error as Error).message);
  console.error('Probá: npm run supabase:diagnose');
  process.exit(1);
});
