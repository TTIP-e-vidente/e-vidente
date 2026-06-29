import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { requireAnonKey, verifyExpressAccessToken } from '../_shared/jwt.ts';
import { mapHandlerError } from '../_shared/handler-errors.ts';
import { getPlayerMe, updatePlayerMe } from '../_shared/services/profile.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    requireAnonKey(req);
    const { sub: userId } = await verifyExpressAccessToken(req.headers.get('Authorization'));

    if (req.method === 'GET') {
      return jsonResponse(await getPlayerMe(userId), 200);
    }
    if (req.method === 'PATCH') {
      const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
      return jsonResponse(await updatePlayerMe(userId, body), 200);
    }
    return errorResponse(405, 'Method not allowed');
  } catch (error) {
    return mapHandlerError(error);
  }
});
