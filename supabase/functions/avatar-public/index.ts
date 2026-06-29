import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { requireAnonKey } from '../_shared/jwt.ts';
import { mapHandlerError } from '../_shared/handler-errors.ts';
import { PlayerError } from '../_shared/player-errors.ts';
import { getAvatarForUser } from '../_shared/services/avatar.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    const url = new URL(req.url);
    const userId = url.searchParams.get('userId')?.trim() ?? '';
    if (!userId) {
      throw new PlayerError(400, 'INVALID_PARAMS', 'userId is required');
    }
    return jsonResponse(await getAvatarForUser(userId), 200);
  } catch (error) {
    return mapHandlerError(error);
  }
});
