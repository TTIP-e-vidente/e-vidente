import { NextFunction, Request, Response } from 'express';
import { getUserFromToken } from './auth.service';
import { PublicUser } from './auth.types';

declare global {
  namespace Express {
    interface Request {
      user?: PublicUser;
    }
  }
}

export async function authenticateToken(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  const authorization = request.header('Authorization');

  if (!authorization?.startsWith('Bearer ')) {
    response.status(401).json({ error: 'Invalid token' });
    return;
  }

  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    response.status(401).json({ error: 'Invalid token' });
    return;
  }

  try {
    request.user = await getUserFromToken(token);
    next();
  } catch {
    response.status(401).json({ error: 'Invalid token' });
  }
}
