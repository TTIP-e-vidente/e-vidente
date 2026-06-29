import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { AuthError, requireAnonKey, verifyExpressAccessToken } from '../_shared/jwt.ts';
import { mapHandlerError } from '../_shared/handler-errors.ts';
import { getLeaderboard } from '../_shared/services/leaderboard.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    const url = new URL(req.url);
    const includeSelf = url.searchParams.get('include_self') === 'true';
    let userId: string | null = null;
    if (includeSelf) {
      try {
        const payload = await verifyExpressAccessToken(req.headers.get('Authorization'));
        userId = payload.sub;
      } catch (error) {
        if (!(error instanceof AuthError)) throw error;
      }
    }

    const data = await getLeaderboard({
      scope: url.searchParams.get('scope') ?? undefined,
      limit: url.searchParams.get('limit') ?? undefined,
      offset: url.searchParams.get('offset') ?? undefined,
      includeSelf,
      userId,
    });
    return jsonResponse(data, 200);
  } catch (error) {
    return mapHandlerError(error);
  }
});
