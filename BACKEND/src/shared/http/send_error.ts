import { Response } from 'express';
import { AppError } from '../errors/app_error';

export function sendError(response: Response, error: unknown): void {
  if (error instanceof AppError) {
    response.status(error.statusCode).json({
      error: error.message,
      code: error.code
    });
    return;
  }

  response.status(500).json({
    error: 'Unexpected error',
    code: 'UNEXPECTED_ERROR'
  });
}
