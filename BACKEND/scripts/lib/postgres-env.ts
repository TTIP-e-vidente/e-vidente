import dotenv from 'dotenv';
import path from 'path';
import { Pool } from 'pg';
import { createPostgresPoolConfig, isRemotePostgres } from '../../src/config/postgresPoolConfig';
import {
  ensureSupabaseConnection,
  type EnsureSupabaseConnectionOptions,
} from './supabase-connect';

export const BACKEND_ROOT = path.resolve(__dirname, '../..');

export type PostgresEnvKind = 'local' | 'staging' | 'production';

/** Archivo env activo: ENV_FILE del proceso o `.env`. */
export function resolveEnvFile(): string {
  return process.env.ENV_FILE?.trim() || '.env';
}

function resolveEnvKind(envFile: string): PostgresEnvKind {
  if (envFile.includes('staging')) {
    return 'staging';
  }
  if (envFile.includes('production')) {
    return 'production';
  }
  return 'local';
}

/** Carga dotenv desde BACKEND/<ENV_FILE|.env> y fija ENV_FILE en el proceso. */
export function loadBackendEnv(): LoadedPostgresEnv {
  const envFile = resolveEnvFile();
  const envPath = path.resolve(BACKEND_ROOT, envFile);
  dotenv.config({ path: envPath });
  process.env.ENV_FILE = envFile;
  return { kind: resolveEnvKind(envFile), envFile, envPath };
}

export interface LoadedPostgresEnv {
  kind: PostgresEnvKind;
  envFile: string;
  envPath: string;
}

export function loadPostgresEnv(kind: PostgresEnvKind): LoadedPostgresEnv {
  const envFile =
    kind === 'staging' ? '.env.staging' : kind === 'production' ? '.env.production' : '.env';
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
  if (!process.env.POSTGRES_HOST?.trim() && !process.env.SUPABASE_PROJECT_REF?.trim()) {
    throw new Error(`Falta POSTGRES_HOST o SUPABASE_PROJECT_REF en ${envPath}`);
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

/** Conecta a Supabase probando direct + pooler; opcionalmente persiste host en el env file. */
export async function connectSupabase(
  options: EnsureSupabaseConnectionOptions = {}
): Promise<{ database: string; user: string }> {
  const result = await ensureSupabaseConnection(options);
  return { database: result.database, user: result.user };
}
