import { isEmailDeliveryConfigured } from './brevo.ts';

const BREVO_ACCOUNT_URL = 'https://api.brevo.com/v3/account';
const PROBE_TIMEOUT_MS = 8000;

export type BrevoProbeResult = {
  ok: boolean;
  checked_at: string;
  error?: string;
  hint?: string;
};

function buildUnauthorizedHint(errorBody: string): string | undefined {
  const lower = errorBody.toLowerCase();
  if (lower.includes('unrecognised ip') || lower.includes('unauthorized')) {
    return (
      'Brevo rechazó la IP de Supabase Edge. Desactivá Authorized IPs o agregá rangos en Brevo → Security.'
    );
  }
  if (lower.includes('not verified') || lower.includes('sender')) {
    return 'El remitente debe estar Verified en Brevo → Senders.';
  }
  return undefined;
}

export async function probeBrevoAccount(): Promise<BrevoProbeResult> {
  const checkedAt = new Date().toISOString();

  if (!isEmailDeliveryConfigured()) {
    return {
      ok: false,
      checked_at: checkedAt,
      error: 'Brevo no configurado (falta BREVO_API_KEY o BREVO_SENDER_EMAIL en secrets)',
    };
  }

  const apiKey = Deno.env.get('BREVO_API_KEY')!.trim();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PROBE_TIMEOUT_MS);

  try {
    const response = await fetch(BREVO_ACCOUNT_URL, {
      method: 'GET',
      headers: {
        'api-key': apiKey,
        accept: 'application/json',
      },
      signal: controller.signal,
    });

    if (response.ok) {
      return { ok: true, checked_at: checkedAt };
    }

    const body = await response.text();
    return {
      ok: false,
      checked_at: checkedAt,
      error: `Brevo account probe failed (${response.status}): ${body.slice(0, 400)}`,
      hint: buildUnauthorizedHint(body),
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      ok: false,
      checked_at: checkedAt,
      error: message,
    };
  } finally {
    clearTimeout(timeout);
  }
}
