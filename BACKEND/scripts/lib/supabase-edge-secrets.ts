import { buildPostgresDatabaseUrl, collectSupabaseClientApiKeys, resolveSupabaseFunctionsUrl } from './supabase-functions-env';

export function buildEdgeFunctionSecrets(): Record<string, string> {
  const secrets: Record<string, string> = {
    DATABASE_URL: buildPostgresDatabaseUrl(),
    JWT_SECRET: process.env.JWT_SECRET?.trim() ?? '',
    EMAIL_CRON_SECRET: process.env.EMAIL_CRON_SECRET?.trim() ?? '',
    BREVO_API_KEY: process.env.BREVO_API_KEY?.trim() ?? '',
    BREVO_SENDER_EMAIL: process.env.BREVO_SENDER_EMAIL?.trim() ?? '',
    BREVO_SENDER_NAME: process.env.BREVO_SENDER_NAME?.trim() ?? 'E-VIDENTE',
    BREVO_WEBHOOK_SECRET: process.env.BREVO_WEBHOOK_SECRET?.trim() ?? '',
    EMAIL_ENABLED: process.env.EMAIL_ENABLED?.trim() || 'true',
    EMAIL_TIMEZONE: process.env.EMAIL_TIMEZONE?.trim() || 'America/Argentina/Buenos_Aires',
    NODE_ENV: process.env.NODE_ENV?.trim() || 'production',
  };

  const clientKeys = collectSupabaseClientApiKeys();
  if (clientKeys.length > 0) {
    secrets.GAME_CLIENT_API_KEYS = clientKeys.join(',');
  }

  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim();
  if (projectRef && !projectRef.includes('TU_')) {
    secrets.SUPABASE_URL = `https://${projectRef}.supabase.co`;
  }

  const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (serviceRole) {
    secrets.SUPABASE_SERVICE_ROLE_KEY = serviceRole;
  }

  return secrets;
}

export function validateEdgeFunctionSecrets(secrets: Record<string, string>): string[] {
  const optional = new Set([
    'BREVO_SENDER_NAME',
    'BREVO_WEBHOOK_SECRET',
    'EMAIL_TIMEZONE',
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'GAME_CLIENT_API_KEYS',
  ]);

  const emailDisabled = secrets.EMAIL_ENABLED === 'false';

  return Object.entries(secrets)
    .filter(([key, value]) => {
      if (optional.has(key)) {
        return false;
      }
      if (emailDisabled && (key === 'BREVO_API_KEY' || key === 'BREVO_SENDER_EMAIL')) {
        return false;
      }
      return value.length === 0;
    })
    .map(([key]) => key);
}

export function resolveSupabaseFunctionsBaseUrl(): string {
  return resolveSupabaseFunctionsUrl();
}
