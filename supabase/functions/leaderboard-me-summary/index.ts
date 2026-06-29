import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { requireAnonKey, verifyExpressAccessToken } from '../_shared/jwt.ts';
import { mapHandlerError } from '../_shared/handler-errors.ts';
import { PlayerError } from '../_shared/player-errors.ts';
import { getUserRankingSummaryPublic } from '../_shared/services/leaderboard.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    const { sub: userId } = await verifyExpressAccessToken(req.headers.get('Authorization'));
    const url = new URL(req.url);
    const scope = url.searchParams.get('scope');
    const data = await getUserRankingSummaryPublic(userId, scope ?? undefined);
    return jsonResponse(data, 200);
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('scope inválido')) {
      return errorResponse(400, error.message, { code: 'INVALID_BODY' });
    }
    if (error instanceof PlayerError) {
      return mapHandlerError(error);
    }
    return mapHandlerError(error);
  }
});
