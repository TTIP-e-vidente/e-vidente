import type { PoolConfig } from 'pg';

function parsePostgresPort(): number {
  const parsed = Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10);
  return Number.isNaN(parsed) ? 5432 : parsed;
}

function parsePositiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isNaN(parsed) || parsed <= 0 ? fallback : parsed;
}

/** Postgres remoto (Supabase, etc.): requiere SSL y no levanta Docker local. */
export function isRemotePostgres(): boolean {
  return process.env.POSTGRES_SSL === 'true';
}

/** Límite recomendado para Supabase Session pooler (free ~15, pro más). */
export function resolvePostgresPoolMax(): number {
  const configured = parsePositiveInt(process.env.POSTGRES_POOL_MAX, 0);
  if (configured > 0) {
    return configured;
  }
  return isRemotePostgres() ? 8 : 10;
}

export function createPostgresPoolConfig(
  overrides: Partial<PoolConfig> = {}
): PoolConfig {
  const remote = isRemotePostgres();

  return {
    host: process.env.POSTGRES_HOST ?? 'localhost',
    port: parsePostgresPort(),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    ssl: remote ? { rejectUnauthorized: false } : undefined,
    max: resolvePostgresPoolMax(),
    idleTimeoutMillis: parsePositiveInt(process.env.POSTGRES_POOL_IDLE_MS, 30_000),
    connectionTimeoutMillis: parsePositiveInt(process.env.POSTGRES_CONNECT_TIMEOUT_MS, 10_000),
    ...overrides,
  };
}

export function describePoolConfig(): {
  max: number;
  ssl: boolean;
  idleTimeoutMillis: number;
  connectionTimeoutMillis: number;
} {
  const config = createPostgresPoolConfig();
  return {
    max: config.max ?? resolvePostgresPoolMax(),
    ssl: Boolean(config.ssl),
    idleTimeoutMillis: config.idleTimeoutMillis ?? 30_000,
    connectionTimeoutMillis: config.connectionTimeoutMillis ?? 10_000,
  };
}
