import { NextFunction, Request, Response } from 'express';
import { getUserFromToken } from '../../modules/auth/auth.service';
import '../types/express-auth-user';

/**
 * Middleware de autenticación opcional.
 * Si hay un Bearer token válido → rellena request.user.
 * Si no hay token o es inválido → continúa sin error (request.user queda undefined).
 * Nunca rechaza con 401.
 */
export async function optionalAuthenticateToken(
  request: Request,
  _response: Response,
  next: NextFunction
): Promise<void> {
  const authorization = request.header('Authorization');

  if (!authorization?.startsWith('Bearer ')) {
    next();
    return;
  }

  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    next();
    return;
  }

  try {
    request.user = await getUserFromToken(token);
  } catch {
    // Token inválido o expirado — ignorar silenciosamente
  }

  next();
}
