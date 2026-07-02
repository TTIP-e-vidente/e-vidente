import { NextFunction, Request, Response } from 'express';
import { getUserFromVerificationCapableToken } from '../../modules/auth/auth.service';
import '../types/express-auth-user';

// Igual que authenticateToken, pero acepta también el token acotado
// (scope email_verification) que devuelve el login cuando el mail no está
// verificado. Solo debe usarse en las rutas de verificación de mail.
export async function authenticateVerificationToken(
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
    request.user = await getUserFromVerificationCapableToken(token);
    next();
  } catch {
    response.status(401).json({ error: 'Invalid token', code: 'INVALID_CREDENTIALS' });
  }
}
