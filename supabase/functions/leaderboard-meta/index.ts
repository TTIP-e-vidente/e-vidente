import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { requireAnonKey } from '../_shared/jwt.ts';
import { mapHandlerError } from '../_shared/handler-errors.ts';
import { getLeaderboardMetaPublic } from '../_shared/services/leaderboard.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    return jsonResponse(await getLeaderboardMetaPublic(), 200);
  } catch (error) {
    return mapHandlerError(error);
  }
});
