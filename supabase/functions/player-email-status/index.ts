import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { requireAnonKey, verifyExpressAccessToken } from '../_shared/jwt.ts';
import { mapHandlerError } from '../_shared/handler-errors.ts';
import { getEmailVerificationStatus } from '../_shared/services/email-status.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    const { sub: userId } = await verifyExpressAccessToken(req.headers.get('Authorization'));
    const status = await getEmailVerificationStatus(userId);
    if (!status) {
      return errorResponse(401, 'Unauthorized');
    }
    return jsonResponse(status, 200);
  } catch (error) {
    return mapHandlerError(error);
  }
});
