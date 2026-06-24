import dotenv from 'dotenv';

dotenv.config();

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
    return true;
  }
  if (normalized === 'false' || normalized === '0' || normalized === 'no') {
    return false;
  }
  return fallback;
}

function resolveEmailEnabled(): boolean {
  const configured = parseBoolean(process.env.EMAIL_ENABLED, false);
  if (!configured) {
    return false;
  }
  if (
    process.env.NODE_ENV === 'test' &&
    !parseBoolean(process.env.EMAIL_ENABLED_IN_TESTS, false)
  ) {
    return false;
  }
  return true;
}

function resolvePublicBaseUrl(): string {
  const configured =
    (process.env.BACKEND_BASE_URL ?? process.env.PUBLIC_API_URL ?? process.env.API_PUBLIC_URL ?? '').trim();
  if (configured.length > 0) {
    return configured.replace(/\/+$/, '');
  }
  if (process.env.NODE_ENV !== 'production') {
    const port = process.env.BACKEND_PORT ?? '3010';
    return `http://localhost:${port}`;
  }
  return '';
}

export const emailConfig = {
  enabled: resolveEmailEnabled(),
  brevoApiKey: process.env.BREVO_API_KEY ?? '',
  senderEmail: process.env.BREVO_SENDER_EMAIL ?? '',
  senderName: process.env.BREVO_SENDER_NAME ?? 'E-VIDENTE',
  cronSecret: process.env.EMAIL_CRON_SECRET ?? '',
  timezone: process.env.EMAIL_TIMEZONE ?? 'America/Argentina/Buenos_Aires',
  pendingStaleMinutes: Number.parseInt(process.env.EMAIL_PENDING_STALE_MINUTES ?? '15', 10),
  batchConcurrency: Math.max(
    1,
    Number.parseInt(process.env.EMAIL_BATCH_CONCURRENCY ?? '5', 10) || 5
  ),
  retryMaxAttempts: Math.max(
    1,
    Number.parseInt(process.env.EMAIL_RETRY_MAX_ATTEMPTS ?? '3', 10) || 3
  ),
  retryMaxAgeHours: Math.max(
    1,
    Number.parseInt(process.env.EMAIL_RETRY_MAX_AGE_HOURS ?? '48', 10) || 48
  ),
  retryBatchLimit: Math.max(
    1,
    Number.parseInt(process.env.EMAIL_RETRY_BATCH_LIMIT ?? '50', 10) || 50
  ),
  requestTimeoutMs: Math.max(
    1000,
    Number.parseInt(process.env.EMAIL_REQUEST_TIMEOUT_MS ?? '15000', 10) || 15000
  ),
  requestMaxAttempts: Math.max(
    1,
    Number.parseInt(process.env.EMAIL_REQUEST_MAX_ATTEMPTS ?? '3', 10) || 3
  ),
  requestRetryBaseMs: Math.max(
    100,
    Number.parseInt(process.env.EMAIL_REQUEST_RETRY_BASE_MS ?? '500', 10) || 500
  ),
  processOnStartup:
    parseBoolean(process.env.EMAIL_PROCESS_ON_STARTUP, process.env.NODE_ENV === 'development'),
  webhookSecret: process.env.BREVO_WEBHOOK_SECRET ?? '',
  pendingWelcomeBatchLimit: Math.max(
    1,
    Number.parseInt(process.env.EMAIL_PENDING_WELCOME_BATCH_LIMIT ?? '25', 10) || 25
  ),
  appPlayUrl: (process.env.EMAIL_APP_PLAY_URL ?? process.env.APP_PLAY_URL ?? '').trim(),
  logoUrl: (process.env.EMAIL_LOGO_URL ?? '').trim(),
  publicBaseUrl: resolvePublicBaseUrl(),
  assetsBaseUrl: (() => {
    const explicit = (process.env.EMAIL_ASSETS_BASE_URL ?? '').trim().replace(/\/+$/, '');
    if (explicit.length > 0) {
      return explicit;
    }
    const publicBase = resolvePublicBaseUrl();
    return publicBase.length > 0 ? `${publicBase}/public/email/assets` : '';
  })(),
  verificationCopySecret:
    (process.env.EMAIL_VERIFICATION_COPY_SECRET ?? process.env.EMAIL_CRON_SECRET ?? '').trim()
};

export function isEmailDeliveryConfigured(): boolean {
  return emailConfig.enabled && emailConfig.brevoApiKey.length > 0 && emailConfig.senderEmail.length > 0;
}
