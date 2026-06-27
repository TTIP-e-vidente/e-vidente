import dotenv from 'dotenv';
import path from 'path';
import { Pool, QueryResult, QueryResultRow } from 'pg';
import { createPostgresPoolConfig } from './postgresPoolConfig';

const envFile = process.env.ENV_FILE ?? '.env';
dotenv.config({ path: path.resolve(process.cwd(), envFile) });

export const pool = new Pool(createPostgresPoolConfig());

export function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<QueryResult<T>> {
  return pool.query<T>(text, params);
}
