import { Response } from 'express';
import { AppError } from '../errors/app_error';

export function sendError(response: Response, error: unknown): void {
  if (error instanceof AppError) {
    response.status(error.statusCode).json({
      error: error.message,
      code: error.code,
      ...(error.details ?? {})
    });
    return;
  }

  console.error('[API] Unexpected error:', error);

  response.status(500).json({
    error: 'Unexpected error',
    code: 'UNEXPECTED_ERROR'
  });
}
