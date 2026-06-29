import { PlayerError } from './player-errors.ts';
import { AuthError as JwtAuthError, ConfigError as JwtConfigError } from './jwt.ts';
import { errorResponse } from './cors.ts';

export function mapHandlerError(error: unknown): Response {
  if (error instanceof PlayerError) {
    return errorResponse(error.statusCode, error.message, { code: error.code });
  }
  if (error instanceof JwtAuthError) {
    return errorResponse(401, error.message);
  }
  if (error instanceof JwtConfigError) {
    return errorResponse(500, error.message);
  }
  console.error('[edge:handler]', error);
  return errorResponse(500, 'Internal server error');
}
