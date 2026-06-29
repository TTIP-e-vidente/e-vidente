import { emailConfig, isEmailDeliveryConfigured } from './email.config';

const BREVO_ACCOUNT_URL = 'https://api.brevo.com/v3/account';

export type BrevoProbeResult = {
  ok: boolean;
  checked_at: string;
  error?: string;
  hint?: string;
};

let lastProbe: BrevoProbeResult | null = null;

export function getLastBrevoProbe(): BrevoProbeResult | null {
  return lastProbe;
}

function buildUnauthorizedHint(errorBody: string): string | undefined {
  const lower = errorBody.toLowerCase();
  if (lower.includes('unrecognised ip') || lower.includes('unauthorized')) {
    return (
      'Brevo rechazó la IP. Agregala en Security → Authorized IPs o desactivá la restricción (ver BACKEND/docs/BREVO_SETUP.md).'
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
    const result: BrevoProbeResult = {
      ok: false,
      checked_at: checkedAt,
      error: 'Brevo no configurado (falta API key o remitente)'
    };
    lastProbe = result;
    return result;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), emailConfig.requestTimeoutMs);

  try {
    const response = await fetch(BREVO_ACCOUNT_URL, {
      method: 'GET',
      headers: {
        'api-key': emailConfig.brevoApiKey,
        accept: 'application/json'
      },
      signal: controller.signal
    });

    if (response.ok) {
      const result: BrevoProbeResult = { ok: true, checked_at: checkedAt };
      lastProbe = result;
      return result;
    }

    const body = await response.text();
    const error = `Brevo account probe failed (${response.status}): ${body.slice(0, 400)}`;
    const result: BrevoProbeResult = {
      ok: false,
      checked_at: checkedAt,
      error,
      hint: buildUnauthorizedHint(body)
    };
    lastProbe = result;
    return result;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const result: BrevoProbeResult = {
      ok: false,
      checked_at: checkedAt,
      error: message
    };
    lastProbe = result;
    return result;
  } finally {
    clearTimeout(timeout);
  }
}

export async function runBrevoStartupProbe(): Promise<void> {
  if (process.env.NODE_ENV === 'test' || !emailConfig.enabled) {
    return;
  }

  if (!isEmailDeliveryConfigured()) {
    return;
  }

  const probe = await probeBrevoAccount();
  if (probe.ok) {
    console.log(`[email] Brevo probe OK (sender=${emailConfig.senderEmail})`);
    return;
  }

  console.error(`[email] Brevo probe FAILED: ${probe.error ?? 'unknown'}`);
  if (probe.hint) {
    console.error(`[email] ${probe.hint}`);
  }
}
