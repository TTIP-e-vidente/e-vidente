import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import {
  AuthError,
  ConfigError,
  requireAnonKey,
  verifyExpressAccessToken,
} from '../_shared/jwt.ts';
import { AuthServiceError, getUserFromToken } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) {
    return cors;
  }

  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    const { sub: userId } = await verifyExpressAccessToken(req.headers.get('Authorization'));
    const user = await getUserFromToken(userId);
    return jsonResponse({ user }, 200);
  } catch (error) {
    if (error instanceof AuthServiceError) {
      return errorResponse(error.statusCode, error.message, { code: error.code });
    }
    if (error instanceof AuthError) {
      return errorResponse(401, error.message);
    }
    if (error instanceof ConfigError) {
      return errorResponse(500, error.message);
    }
    console.error('[auth-me]', error);
    return errorResponse(500, 'Internal server error');
  }
});
