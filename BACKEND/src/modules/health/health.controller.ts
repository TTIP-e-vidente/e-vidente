import { Request, Response } from 'express';
import { query } from '../../config/database';

export function getHealth(_request: Request, response: Response): void {
  response.json({ status: 'ok' });
}

export async function getDatabaseHealth(_request: Request, response: Response): Promise<void> {
  const result = await query<{ current_database: string; current_user: string }>(
    'SELECT current_database(), current_user;'
  );

  response.json({
    status: 'ok',
    database: result.rows[0].current_database,
    user: result.rows[0].current_user
  });
}
