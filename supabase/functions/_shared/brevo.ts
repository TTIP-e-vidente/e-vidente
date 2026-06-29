export type { EmailMessage } from './email/email-types.ts';
export {
  buildStreakAtRiskEmail,
  buildStreakLostEmail,
  buildVerificationEmail,
  buildWelcomeEmail,
} from './email/build-messages.ts';

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
  message: import('./email/email-types.ts').EmailMessage,
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
