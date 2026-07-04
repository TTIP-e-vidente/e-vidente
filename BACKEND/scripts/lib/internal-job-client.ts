import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './supabase-functions-env';
import { emailConfig } from '../../src/modules/email/email.config';

/** Jobs programados hoy en pg_cron (migración 040). */
export const CONFIGURED_CRON_JOBS = [
  'streak-at-risk-emails',
  'streak-last-chance-emails',
  'streak-lost-emails',
  'retry-failed-emails',
  'refresh-leaderboard',
] as const;

export type ConfiguredCronJob = (typeof CONFIGURED_CRON_JOBS)[number];

export const ALL_INTERNAL_JOBS = new Set<string>([
  ...CONFIGURED_CRON_JOBS,
  'streak-emails',
  'outbound-emails',
]);

export interface InternalJobResult {
  job: string;
  status: number;
  body: string;
}

export function assertInternalJobEnv(): { baseUrl: string; anonKey: string; secret: string } {
  const secret = emailConfig.cronSecret?.trim();
  if (!secret) {
    throw new Error('EMAIL_CRON_SECRET vacío en el env activo');
  }
  if (!canUseSupabaseEmailFunctions()) {
    throw new Error('Faltan SUPABASE_ANON_KEY / SUPABASE_PROJECT_REF — npm run configure:supabase-keys');
  }
  return {
    baseUrl: resolveSupabaseFunctionsUrl(),
    anonKey: resolveSupabaseClientApiKey(),
    secret,
  };
}

export interface TriggerInternalJobOptions {
  baseUrl?: string;
  anonKey?: string;
  secret?: string;
  onlyUserId?: string;
  retryBatchLimit?: number;
}

export async function triggerInternalJob(
  job: string,
  options: TriggerInternalJobOptions = {},
): Promise<InternalJobResult> {
  if (!ALL_INTERNAL_JOBS.has(job)) {
    throw new Error(`Job no soportado: ${job}`);
  }

  const resolved = options.baseUrl && options.anonKey && options.secret
    ? { baseUrl: options.baseUrl, anonKey: options.anonKey, secret: options.secret }
    : assertInternalJobEnv();

  const body: Record<string, unknown> = { job };
  if (options.onlyUserId) {
    body.onlyUserId = options.onlyUserId;
  }
  if (options.retryBatchLimit) {
    body.retryBatchLimit = options.retryBatchLimit;
  }

  const url = `${resolved.baseUrl}/internal-job`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: resolved.anonKey,
      Authorization: `Bearer ${resolved.anonKey}`,
      'X-Job-Secret': resolved.secret,
    },
    body: JSON.stringify(body),
  });

  const responseBody = await response.text();
  return { job, status: response.status, body: responseBody };
}
