import { Response } from 'express';

export function sendResponse(response: Response, statusCode: number, data: unknown): void {
  response.status(statusCode).json(data);
}
