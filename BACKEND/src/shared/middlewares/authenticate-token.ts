import { NextFunction, Request, Response } from 'express';
import { getUserFromToken } from '../../modules/auth/auth.service';
import '../types/express-auth-user';

export async function authenticateToken(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  const authorization = request.header('Authorization');

  if (!authorization?.startsWith('Bearer ')) {
    response.status(401).json({ error: 'Invalid token', code: 'INVALID_CREDENTIALS' });
    return;
  }

  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    response.status(401).json({ error: 'Invalid token', code: 'INVALID_CREDENTIALS' });
    return;
  }

  try {
    request.user = await getUserFromToken(token);
    next();
  } catch {
    response.status(401).json({ error: 'Invalid token', code: 'INVALID_CREDENTIALS' });
  }
}
