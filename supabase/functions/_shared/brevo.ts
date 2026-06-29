export interface EmailMessage {
  to: string;
  toName: string;
  subject: string;
  htmlContent: string;
  textContent: string;
}

const BREVO_URL = 'https://api.brevo.com/v3/smtp/email';

export function isEmailDeliveryConfigured(): boolean {
  const enabled = (Deno.env.get('EMAIL_ENABLED') ?? 'true').trim().toLowerCase();
  if (['false', '0', 'no'].includes(enabled)) {
    return false;
  }
  const apiKey = Deno.env.get('BREVO_API_KEY')?.trim() ?? '';
  const sender = Deno.env.get('BREVO_SENDER_EMAIL')?.trim() ?? '';
  return apiKey.length > 0 && sender.includes('@');
}

export function isDevelopmentEnvironment(): boolean {
  const nodeEnv = (Deno.env.get('NODE_ENV') ?? '').trim().toLowerCase();
  return nodeEnv === 'development';
}

export async function sendTransactionalEmail(
  message: EmailMessage,
  templateKey?: string,
): Promise<string | null> {
  if (!isEmailDeliveryConfigured()) {
    return null;
  }

  const apiKey = Deno.env.get('BREVO_API_KEY')!.trim();
  const senderEmail = Deno.env.get('BREVO_SENDER_EMAIL')!.trim();
  const senderName = (Deno.env.get('BREVO_SENDER_NAME') ?? 'E-VIDENTE').trim();

  const payload: Record<string, unknown> = {
    sender: { name: senderName, email: senderEmail },
    to: [{ email: message.to, name: message.toName }],
    subject: message.subject,
    htmlContent: message.htmlContent,
    textContent: message.textContent,
  };
  if (templateKey) {
    payload.tags = [templateKey];
  }

  const response = await fetch(BREVO_URL, {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'Content-Type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Brevo ${response.status}: ${body.slice(0, 300)}`);
  }

  const body = (await response.json()) as { messageId?: string };
  return typeof body.messageId === 'string' ? body.messageId : null;
}

export function buildVerificationEmail(input: {
  name: string;
  mail: string;
  code: string;
  expiresMinutes: number;
}): EmailMessage {
  const digits = input.code.replace(/\D/g, '').slice(0, 6);
  const safeName = input.name.trim() || 'Jugador';
  const subject = `Código E-VIDENTE: ${digits} (verificá tu mail)`;
  const textContent = [
    `Hola ${safeName},`,
    '',
    `Tu código de verificación es: ${digits}`,
    `Válido por ${input.expiresMinutes} minutos.`,
    '',
    'Copiá el código y pegalo en el juego.',
    '',
    '— Equipo E-VIDENTE',
  ].join('\n');

  const htmlContent = `<!DOCTYPE html><html><body style="font-family:sans-serif;color:#1a1a1a;">
<p>Hola <strong>${escapeHtml(safeName)}</strong>,</p>
<p>Tu código de verificación para E-VIDENTE:</p>
<p style="font-size:28px;letter-spacing:6px;font-weight:bold;">${digits}</p>
<p>Válido por ${input.expiresMinutes} minutos. Copialo y pegalo en el juego.</p>
<p style="color:#666;font-size:13px;">Si no lo pediste, ignorá este mail.</p>
<p>— Equipo E-VIDENTE</p>
</body></html>`;

  return {
    to: input.mail.trim(),
    toName: safeName,
    subject,
    htmlContent,
    textContent,
  };
}

export function buildWelcomeEmail(input: {
  name: string;
  mail: string;
}): EmailMessage {
  const safeName = input.name.trim() || 'Jugador';
  const subject = '¡Bienvenido/a a E-VIDENTE!';
  const textContent = [
    `Hola ${safeName},`,
    '',
    'Tu mail quedó verificado. ¡Gracias por unirte a E-VIDENTE!',
    '',
    '— Equipo E-VIDENTE',
  ].join('\n');
  const htmlContent = `<!DOCTYPE html><html><body style="font-family:sans-serif;">
<p>Hola <strong>${escapeHtml(safeName)}</strong>,</p>
<p>Tu mail quedó verificado. ¡Gracias por unirte a E-VIDENTE!</p>
<p>— Equipo E-VIDENTE</p>
</body></html>`;
  return {
    to: input.mail.trim(),
    toName: safeName,
    subject,
    htmlContent,
    textContent,
  };
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
