import { Pool, QueryResult, QueryResultRow } from 'pg';
import { loadEnvFile } from './load-env';
import { createPostgresPoolConfig } from './postgresPoolConfig';

loadEnvFile();

export const pool = new Pool(createPostgresPoolConfig());

export function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<QueryResult<T>> {
  return pool.query<T>(text, params);
}
