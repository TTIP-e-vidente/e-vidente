import { buildPostgresDatabaseUrl } from './supabase-functions-env';

export function buildEdgeFunctionSecrets(): Record<string, string> {
  const secrets: Record<string, string> = {
    DATABASE_URL: buildPostgresDatabaseUrl(),
    JWT_SECRET: process.env.JWT_SECRET?.trim() ?? '',
    EMAIL_CRON_SECRET: process.env.EMAIL_CRON_SECRET?.trim() ?? '',
    BREVO_API_KEY: process.env.BREVO_API_KEY?.trim() ?? '',
    BREVO_SENDER_EMAIL: process.env.BREVO_SENDER_EMAIL?.trim() ?? '',
    BREVO_SENDER_NAME: process.env.BREVO_SENDER_NAME?.trim() ?? 'E-VIDENTE',
    EMAIL_ENABLED: process.env.EMAIL_ENABLED?.trim() || 'true',
    EMAIL_TIMEZONE: process.env.EMAIL_TIMEZONE?.trim() || 'America/Argentina/Buenos_Aires',
    NODE_ENV: process.env.NODE_ENV?.trim() || 'production',
  };

  const backendUrl = (process.env.BACKEND_BASE_URL ?? '').trim().replace(/\/+$/, '');
  if (backendUrl) {
    secrets.BACKEND_BASE_URL = backendUrl;
  }

  return secrets;
}

export function validateEdgeFunctionSecrets(secrets: Record<string, string>): string[] {
  const optional = new Set(['BREVO_SENDER_NAME', 'BACKEND_BASE_URL', 'EMAIL_TIMEZONE']);
  return Object.entries(secrets)
    .filter(([key, value]) => !optional.has(key) && value.length === 0)
    .map(([key]) => key);
}
