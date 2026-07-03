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
    EMAIL_APP_PLAY_URL: process.env.EMAIL_APP_PLAY_URL?.trim() || process.env.APP_PLAY_URL?.trim() || '',
    EMAIL_ASSETS_BASE_URL: process.env.EMAIL_ASSETS_BASE_URL?.trim() || '',
    EMAIL_LOGO_URL: process.env.EMAIL_LOGO_URL?.trim() || '',
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
    'EMAIL_APP_PLAY_URL',
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'GAME_CLIENT_API_KEYS',
  ]);

  // Solo obligatorios si el envío de mails está prendido: sin esto, el logo y
  // los íconos se mandan en base64 inline, que Brevo/los clientes de mail no
  // renderizan de forma confiable (ver BACKEND/docs/EMAILS_RUNBOOK.md §6).
  const emailDisabled = secrets.EMAIL_ENABLED === 'false';
  const requiredOnlyWhenEmailEnabled = new Set([
    'BREVO_API_KEY',
    'BREVO_SENDER_EMAIL',
    'EMAIL_LOGO_URL',
    'EMAIL_ASSETS_BASE_URL',
  ]);

  return Object.entries(secrets)
    .filter(([key, value]) => {
      if (optional.has(key)) {
        return false;
      }
      if (emailDisabled && requiredOnlyWhenEmailEnabled.has(key)) {
        return false;
      }
      return value.length === 0;
    })
    .map(([key]) => key);
}

export function resolveSupabaseFunctionsBaseUrl(): string {
  return resolveSupabaseFunctionsUrl();
}
