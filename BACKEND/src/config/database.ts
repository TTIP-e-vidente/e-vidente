import dotenv from 'dotenv';
import { Pool, QueryResult, QueryResultRow } from 'pg';

dotenv.config();

const postgresPort = Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10);

export const pool = new Pool({
  host: process.env.POSTGRES_HOST ?? 'localhost',
  port: Number.isNaN(postgresPort) ? 5432 : postgresPort,
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD
});

export function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<QueryResult<T>> {
  return pool.query<T>(text, params);
}
