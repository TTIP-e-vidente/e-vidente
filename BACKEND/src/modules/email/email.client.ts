import { emailConfig, isEmailDeliveryConfigured } from './email.config';
import { EmailMessage } from './email.types';

export class EmailDeliveryError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EmailDeliveryError';
  }
}

const BREVO_TRANSACTIONAL_URL = 'https://api.brevo.com/v3/smtp/email';

function buildBrevoHeaders(): Record<string, string> {
  return {
    'api-key': emailConfig.brevoApiKey,
    'Content-Type': 'application/json',
    accept: 'application/json'
  };
}

function buildBrevoPayload(message: EmailMessage): Record<string, unknown> {
  return {
    sender: {
      name: emailConfig.senderName,
      email: emailConfig.senderEmail
    },
    to: [{ email: message.to, name: message.toName }],
    subject: message.subject,
    htmlContent: message.htmlContent,
    textContent: message.textContent
  };
}

export async function sendTransactionalEmail(message: EmailMessage): Promise<string | null> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] delivery skipped: EMAIL_ENABLED=false or missing Brevo config');
    return null;
  }

  const response = await fetch(BREVO_TRANSACTIONAL_URL, {
    method: 'POST',
    headers: buildBrevoHeaders(),
    body: JSON.stringify(buildBrevoPayload(message))
  });

  if (!response.ok) {
    const body = await response.text();
    throw new EmailDeliveryError(
      `Brevo request failed (${response.status}): ${body.slice(0, 300)}`
    );
  }

  const payload = (await response.json()) as { messageId?: string };
  return typeof payload.messageId === 'string' ? payload.messageId : null;
}
