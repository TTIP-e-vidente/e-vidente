import dotenv from 'dotenv';
import path from 'path';
import { Pool } from 'pg';
import { createPostgresPoolConfig, isRemotePostgres } from '../../src/config/postgresPoolConfig';

export const BACKEND_ROOT = path.resolve(__dirname, '../..');

export type PostgresEnvKind = 'local' | 'staging';

/** Archivo env activo: ENV_FILE del proceso o `.env`. */
export function resolveEnvFile(): string {
  return process.env.ENV_FILE?.trim() || '.env';
}

/** Carga dotenv desde BACKEND/<ENV_FILE|.env> y fija ENV_FILE en el proceso. */
export function loadBackendEnv(): LoadedPostgresEnv {
  const envFile = resolveEnvFile();
  const envPath = path.resolve(BACKEND_ROOT, envFile);
  dotenv.config({ path: envPath });
  process.env.ENV_FILE = envFile;
  const kind: PostgresEnvKind = envFile === '.env.staging' ? 'staging' : 'local';
  return { kind, envFile, envPath };
}

export interface LoadedPostgresEnv {
  kind: PostgresEnvKind;
  envFile: string;
  envPath: string;
}

export function loadPostgresEnv(kind: PostgresEnvKind): LoadedPostgresEnv {
  const envFile = kind === 'staging' ? '.env.staging' : '.env';
  const envPath = path.resolve(BACKEND_ROOT, envFile);
  dotenv.config({ path: envPath });
  process.env.ENV_FILE = envFile;
  return { kind, envFile, envPath };
}

export function describeConnection(): string {
  const host = process.env.POSTGRES_HOST ?? 'localhost';
  const port = process.env.POSTGRES_PORT ?? '5432';
  const database = process.env.POSTGRES_DB ?? '?';
  const user = process.env.POSTGRES_USER ?? '?';
  const ssl = isRemotePostgres() ? 'ssl' : 'no-ssl';
  return `${user}@${host}:${port}/${database} (${ssl})`;
}

export function assertSupabaseStagingEnv(envPath: string): void {
  if (!isRemotePostgres()) {
    throw new Error(
      `POSTGRES_SSL=true es obligatorio en Supabase. Completá ${envPath} (copiá desde .env.staging.example).`
    );
  }
  if (!process.env.POSTGRES_PASSWORD?.trim()) {
    throw new Error(`Falta POSTGRES_PASSWORD en ${envPath}`);
  }
  if (!process.env.POSTGRES_HOST?.trim()) {
    throw new Error(`Falta POSTGRES_HOST en ${envPath}`);
  }
}

export function assertLocalDockerEnv(): void {
  if (isRemotePostgres()) {
    throw new Error(
      'Este paso usa Postgres local (Docker). POSTGRES_SSL debe ser false en BACKEND/.env'
    );
  }
}

export function createPoolFromCurrentEnv(overrides: { connectionTimeoutMillis?: number } = {}): Pool {
  return new Pool(createPostgresPoolConfig(overrides));
}

export async function validatePoolConnection(pool: Pool): Promise<{
  database: string;
  user: string;
}> {
  const result = await pool.query<{ current_database: string; current_user: string }>(
    'SELECT current_database(), current_user;'
  );
  const row = result.rows[0];
  return { database: row.current_database, user: row.current_user };
}
