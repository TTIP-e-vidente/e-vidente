import { execSync } from 'child_process';
import dotenv from 'dotenv';
import path from 'path';
import { Pool } from 'pg';
import { createPostgresPoolConfig, isRemotePostgres } from '../src/config/postgresPoolConfig';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const PROJECT_ROOT = path.resolve(__dirname, '..');

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

function isDockerAvailable(): boolean {
  try {
    execSync('docker info', { cwd: PROJECT_ROOT, stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function startPostgresContainer(): void {
  console.log('[postgres] levantando contenedor con docker compose up -d...');
  execSync('docker compose up -d', { cwd: PROJECT_ROOT, stdio: 'inherit' });
}

async function waitForPostgres(maxRetries = 20, delayMs = 2000): Promise<void> {
  const pool = createPool();

  try {
    for (let attempt = 1; attempt <= maxRetries; attempt += 1) {
      if (await canConnect(pool)) {
        console.log('[postgres] conexión OK');
        return;
      }

      if (attempt === maxRetries) {
        break;
      }

      console.log(`[postgres] esperando PostgreSQL... (${attempt}/${maxRetries})`);
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  } finally {
    await pool.end();
  }

  console.error('\nERROR: PostgreSQL no responde en el puerto configurado.');
  console.error('Verificá BACKEND/.env (POSTGRES_PORT=5433) y que Docker Desktop esté abierto.');
  console.error('Luego corré: docker compose up -d');
  process.exit(1);
}

export async function ensurePostgres(): Promise<void> {
  const pool = createPool();

  try {
    if (await canConnect(pool)) {
      return;
    }
  } finally {
    await pool.end();
  }

  if (isRemotePostgres()) {
    console.error('\nERROR: no se puede conectar a PostgreSQL remoto (POSTGRES_SSL=true).');
    console.error('Verificá credenciales en BACKEND/.env y que el proyecto Supabase esté activo.');
    process.exit(1);
  }

  if (!isDockerAvailable()) {
    console.error('\nERROR: no se puede conectar a PostgreSQL y Docker no está disponible.');
    console.error('Abrí Docker Desktop y volvé a correr npm run dev.');
    console.error('Si ya está abierto, ejecutá en BACKEND: docker compose up -d');
    process.exit(1);
  }

  startPostgresContainer();
  await waitForPostgres();
}

if (require.main === module) {
  ensurePostgres().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
