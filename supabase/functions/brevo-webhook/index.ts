import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import {
  handleBrevoWebhookEvents,
  type BrevoWebhookEvent,
} from '../_shared/services/brevo-webhook.ts';

function isAuthorized(req: Request): boolean {
  const expected = Deno.env.get('BREVO_WEBHOOK_SECRET')?.trim();
  if (!expected) {
    return false;
  }
  const provided = req.headers.get('X-Brevo-Webhook-Secret')?.trim() ?? '';
  return provided === expected;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) {
    return cors;
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed');
  }

  if (!isAuthorized(req)) {
    return errorResponse(401, 'Unauthorized webhook secret');
  }

  try {
    const body = await req.json();
    const events: BrevoWebhookEvent[] = Array.isArray(body) ? body : [body as BrevoWebhookEvent];
    const result = await handleBrevoWebhookEvents(events);
    return jsonResponse(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return errorResponse(500, message);
  }
});
