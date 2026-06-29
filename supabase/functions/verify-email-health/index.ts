import { handleCors, jsonResponse } from '../_shared/cors.ts';
import { isEmailDeliveryConfigured } from '../_shared/brevo.ts';
import { probeBrevoAccount } from '../_shared/brevo-probe.ts';

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
  const senderEmail = (Deno.env.get('BREVO_SENDER_EMAIL') ?? '').trim();
  const brevoProbe = configured ? await probeBrevoAccount() : null;

  const hints: string[] = [];
  if (!configured) {
    hints.push('Configurá BREVO_API_KEY y BREVO_SENDER_EMAIL en secrets de Supabase Edge Functions.');
  } else if (brevoProbe && !brevoProbe.ok) {
    if (brevoProbe.hint) {
      hints.push(brevoProbe.hint);
    } else if (brevoProbe.error) {
      hints.push(brevoProbe.error);
    }
  }

  return jsonResponse({
    ok: true,
    source: 'supabase-edge',
    email_enabled: emailEnabled,
    delivery_configured: configured && (brevoProbe?.ok ?? false),
    sender_email: senderEmail.includes('@') ? senderEmail : null,
    brevo_probe: brevoProbe,
    hints,
  });
});
