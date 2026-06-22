import { emailConfig, isEmailDeliveryConfigured } from './email.config';
import { EmailMessage, EmailTemplateKey } from './email.types';

export class EmailDeliveryError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EmailDeliveryError';
  }
}

const BREVO_TRANSACTIONAL_URL = 'https://api.brevo.com/v3/smtp/email';

export interface SendTransactionalEmailOptions {
  templateKey?: EmailTemplateKey;
}

function buildBrevoHeaders(): Record<string, string> {
  return {
    'api-key': emailConfig.brevoApiKey,
    'Content-Type': 'application/json',
    accept: 'application/json'
  };
}

function buildBrevoPayload(
  message: EmailMessage,
  templateKey?: EmailTemplateKey
): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    sender: {
      name: emailConfig.senderName,
      email: emailConfig.senderEmail
    },
    to: [{ email: message.to, name: message.toName }],
    subject: message.subject,
    htmlContent: message.htmlContent,
    textContent: message.textContent
  };

  if (templateKey) {
    payload.tags = [templateKey];
  }

  // Brevo transactional no soporta CID inline: las imágenes van por URL pública en el HTML.
  return payload;
}

function isRetryableStatus(status: number): boolean {
  return status === 429 || status >= 500;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function formatFetchError(error: unknown): string {
  if (error instanceof Error) {
    if (error.name === 'AbortError') {
      return `Brevo request timed out after ${emailConfig.requestTimeoutMs}ms`;
    }
    return error.message;
  }
  return String(error);
}

async function postToBrevo(payload: Record<string, unknown>): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), emailConfig.requestTimeoutMs);

  try {
    return await fetch(BREVO_TRANSACTIONAL_URL, {
      method: 'POST',
      headers: buildBrevoHeaders(),
      body: JSON.stringify(payload),
      signal: controller.signal
    });
  } finally {
    clearTimeout(timeout);
  }
}

export async function sendTransactionalEmail(
  message: EmailMessage,
  options: SendTransactionalEmailOptions = {}
): Promise<string | null> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] delivery skipped: EMAIL_ENABLED=false or missing Brevo config');
    return null;
  }

  const payload = buildBrevoPayload(message, options.templateKey);
  const maxAttempts = emailConfig.requestMaxAttempts;
  let lastErrorMessage = 'Brevo request failed';

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const response = await postToBrevo(payload);

      if (response.ok) {
        const body = (await response.json()) as { messageId?: string };
        return typeof body.messageId === 'string' ? body.messageId : null;
      }

      const body = await response.text();
      lastErrorMessage = `Brevo request failed (${response.status}): ${body.slice(0, 300)}`;

      if (!isRetryableStatus(response.status) || attempt === maxAttempts) {
        throw new EmailDeliveryError(lastErrorMessage);
      }
    } catch (error) {
      if (error instanceof EmailDeliveryError) {
        throw error;
      }

      lastErrorMessage = formatFetchError(error);
      if (attempt === maxAttempts) {
        throw new EmailDeliveryError(lastErrorMessage);
      }
    }

    const backoffMs = emailConfig.requestRetryBaseMs * attempt;
    console.warn(
      `[email] Brevo attempt ${attempt}/${maxAttempts} failed, retrying in ${backoffMs}ms`
    );
    await sleep(backoffMs);
  }

  throw new EmailDeliveryError(lastErrorMessage);
}
