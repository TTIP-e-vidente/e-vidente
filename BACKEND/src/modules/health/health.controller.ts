import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { getDbInfo } from './health.repository';

export function getHealth(_request: Request, response: Response): void {
  sendResponse(response, 200, { status: 'ok' });
}

export async function getDatabaseHealth(_request: Request, response: Response): Promise<void> {
  try {
    const info = await getDbInfo();
    sendResponse(response, 200, {
      status: 'ok',
      database: info.current_database,
      user: info.current_user
    });
  } catch (error) {
    sendError(response, error);
  }
}
