import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send_error';
import { getDbInfo } from './health.repository';

export function getHealth(_request: Request, response: Response): void {
  response.json({ status: 'ok' });
}

export async function getDatabaseHealth(_request: Request, response: Response): Promise<void> {
  try {
    const info = await getDbInfo();
    response.json({
      status: 'ok',
      database: info.current_database,
      user: info.current_user
    });
  } catch (error) {
    sendError(response, error);
  }
}
