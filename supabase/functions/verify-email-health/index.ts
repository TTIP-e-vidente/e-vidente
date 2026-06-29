import { handleCors, jsonResponse } from '../_shared/cors.ts';
import { isEmailDeliveryConfigured } from '../_shared/brevo.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) {
    return cors;
  }

  if (req.method !== 'GET') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const emailEnabled = !['false', '0', 'no'].includes(
    (Deno.env.get('EMAIL_ENABLED') ?? 'true').trim().toLowerCase(),
  );
  const configured = isEmailDeliveryConfigured();

  return jsonResponse({
    ok: true,
    source: 'supabase-edge',
    email_enabled: emailEnabled,
    delivery_configured: configured,
    hints: configured
      ? []
      : ['Configurá BREVO_API_KEY y BREVO_SENDER_EMAIL en secrets de Supabase Edge Functions.'],
  });
});
