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

export const emailConfig = {
  enabled: parseBoolean(process.env.EMAIL_ENABLED, false),
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
  )
};

export function isEmailDeliveryConfigured(): boolean {
  return emailConfig.enabled && emailConfig.brevoApiKey.length > 0 && emailConfig.senderEmail.length > 0;
}
