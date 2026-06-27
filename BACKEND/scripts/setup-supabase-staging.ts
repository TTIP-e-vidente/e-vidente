import dotenv from 'dotenv';
import path from 'path';
import { Pool } from 'pg';
import { createPostgresPoolConfig, isRemotePostgres } from '../src/config/postgresPoolConfig';

const PROJECT_ROOT = path.resolve(__dirname, '..');
const STAGING_ENV_PATH = path.resolve(PROJECT_ROOT, '.env.staging');

dotenv.config({ path: STAGING_ENV_PATH });
process.env.ENV_FILE = '.env.staging';

async function validateConnection(pool: Pool): Promise<void> {
  const result = await pool.query<{ current_database: string; current_user: string }>(
    'SELECT current_database(), current_user;'
  );
  const row = result.rows[0];
  console.log(`Conexión OK — DB: ${row.current_database} | user: ${row.current_user}`);
}

async function main(): Promise<void> {
  if (!isRemotePostgres()) {
    console.error('ERROR: POSTGRES_SSL=true es obligatorio para setup Supabase.');
    console.error(`Copiá .env.staging.example → ${STAGING_ENV_PATH} y completá credenciales.`);
    process.exit(1);
  }

  if (!process.env.POSTGRES_PASSWORD) {
    console.error('ERROR: falta POSTGRES_PASSWORD en .env.staging');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Setup Supabase (staging)');
  console.log('═══════════════════════════════════════════');
  console.log('\nTip: para migraciones usá conexión DIRECT en .env.staging');
  console.log('(db.<project-ref>.supabase.co, user postgres). Luego volvé al session pooler.\n');

  const pool = new Pool(createPostgresPoolConfig({ connectionTimeoutMillis: 10000 }));

  try {
    await validateConnection(pool);
  } catch (error) {
    console.error('ERROR: no se pudo conectar a Supabase.');
    console.error((error as Error).message);
    process.exit(1);
  } finally {
    await pool.end();
  }

  const { execSync } = await import('child_process');
  execSync('npx ts-node scripts/run-migrations.ts', {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    env: { ...process.env },
  });

  console.log('\nMigraciones aplicadas. Próximo paso: npm run smoke:api (con .env.staging cargado).');
}

main().catch((error) => {
  console.error('\nSetup Supabase falló:', error);
  process.exit(1);
});
