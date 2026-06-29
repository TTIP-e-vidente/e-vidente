import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { requireAnonKey, verifyExpressAccessToken } from '../_shared/jwt.ts';
import { mapHandlerError } from '../_shared/handler-errors.ts';
import { saveProgressBatch } from '../_shared/services/progress.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    const { sub: userId } = await verifyExpressAccessToken(req.headers.get('Authorization'));
    const body = (await req.json().catch(() => ({}))) as { items?: unknown };
    const data = await saveProgressBatch(userId, body.items ?? []);
    return jsonResponse(data, 200);
  } catch (error) {
    return mapHandlerError(error);
  }
});
