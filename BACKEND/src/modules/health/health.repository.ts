import { query } from '../../config/database';

export interface DbInfoRow {
  current_database: string;
  current_user: string;
}

export async function getDbInfo(): Promise<DbInfoRow> {
  const result = await query<DbInfoRow>('SELECT current_database(), current_user;');
  return result.rows[0];
}
