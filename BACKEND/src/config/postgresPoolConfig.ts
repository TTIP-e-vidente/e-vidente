import type { PoolConfig } from 'pg';

function parsePostgresPort(): number {
  const parsed = Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10);
  return Number.isNaN(parsed) ? 5432 : parsed;
}

/** Postgres remoto (Supabase, etc.): requiere SSL y no levanta Docker local. */
export function isRemotePostgres(): boolean {
  return process.env.POSTGRES_SSL === 'true';
}

export function createPostgresPoolConfig(
  overrides: Partial<PoolConfig> = {}
): PoolConfig {
  return {
    host: process.env.POSTGRES_HOST ?? 'localhost',
    port: parsePostgresPort(),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    ssl: isRemotePostgres() ? { rejectUnauthorized: false } : undefined,
    ...overrides,
  };
}
