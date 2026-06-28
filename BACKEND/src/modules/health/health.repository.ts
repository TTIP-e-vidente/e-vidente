import { query } from '../../config/database';

export interface DbInfoRow {
  current_database: string;
  current_user: string;
}

export async function getDbInfo(): Promise<DbInfoRow> {
  const result = await query<DbInfoRow>('SELECT current_database(), current_user;');
  return result.rows[0];
}

export async function getAppliedMigrationCount(): Promise<number> {
  const result = await query<{ count: string }>(
    'SELECT COUNT(*)::text AS count FROM schema_migrations;'
  );
  return Number.parseInt(result.rows[0]?.count ?? '0', 10);
}
