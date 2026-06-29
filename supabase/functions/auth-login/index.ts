import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { AuthError, ConfigError, requireAnonKey } from '../_shared/jwt.ts';
import { AuthServiceError, login } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) {
    return cors;
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const result = await login(body);
    return jsonResponse(result, 200);
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
    console.error('[auth-login]', error);
    return errorResponse(500, 'Internal server error');
  }
});
