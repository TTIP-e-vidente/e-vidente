import { Pool } from 'pg';
import { createPostgresPoolConfig, isRemotePostgres } from '../src/config/postgresPoolConfig';
import { connectSupabase, loadBackendEnv } from './lib/postgres-env';
import { assertSupabaseOnlyDev } from './lib/supabase-only-policy';

const { envFile } = loadBackendEnv();

function createPool(): Pool {
  return new Pool(createPostgresPoolConfig({ connectionTimeoutMillis: 3000 }));
}

async function canConnect(pool: Pool): Promise<boolean> {
  try {
    const client = await pool.connect();
    client.release();
    return true;
  } catch {
    return false;
  }
}

export async function ensurePostgres(): Promise<void> {
  assertSupabaseOnlyDev('ensurePostgres');

  const { envPath } = loadBackendEnv();
  const pool = createPool();

  try {
    if (await canConnect(pool)) {
      return;
    }
  } finally {
    await pool.end();
  }

  if (!isRemotePostgres()) {
    console.error('\n✗ Postgres local/Docker no está soportado.');
    console.error(`  Env: ${envFile} — configurá POSTGRES_SSL=true (Supabase).`);
    console.error('  Guía: docs/SUPABASE_QUICKSTART.md\n');
    process.exit(1);
  }

  console.log('[postgres] reintentando conexión Supabase (fallback pooler)…');
  try {
    await connectSupabase({ envPath, persistToEnvFile: true, silent: false });
  } catch (error) {
    console.error('\nERROR: no se puede conectar a PostgreSQL remoto (Supabase).');
    console.error((error as Error).message);
    console.error('\nProbá: npm run supabase:diagnose');
    process.exit(1);
  }

  const retryPool = createPool();
  try {
    if (await canConnect(retryPool)) {
      return;
    }
  } finally {
    await retryPool.end();
  }

  console.error('\nERROR: Supabase respondió en diagnose pero el pool local falla.');
  process.exit(1);
}

if (require.main === module) {
  ensurePostgres().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
