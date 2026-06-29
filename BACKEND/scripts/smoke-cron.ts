/**
 * Prueba internal-job en Supabase Edge (mismo camino que pg_cron).
 *
 * Uso:
 *   npm run smoke:cron:staging
 *   npm run smoke:cron:staging -- streak-at-risk-emails
 */
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';
import { emailConfig } from '../src/modules/email/email.config';

const ALLOWED_JOBS = new Set([
  'streak-emails',
  'streak-at-risk-emails',
  'streak-lost-emails',
  'retry-failed-emails',
  'outbound-emails',
  'refresh-leaderboard',
]);

async function triggerEdgeJob(baseUrl: string, anonKey: string, secret: string, job: string): Promise<void> {
  const url = `${baseUrl}/internal-job`;
  console.log(`POST ${url} (job=${job})`);
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      'X-Job-Secret': secret,
    },
    body: JSON.stringify({ job }),
  });
  const text = await response.text();
  console.log(`HTTP ${response.status}`);
  console.log(text);
  if (response.status < 200 || response.status >= 300) {
    process.exit(1);
  }
}

async function main(): Promise<void> {
  loadStagingWithKeys();

  const job = process.argv[2] ?? 'outbound-emails';
  if (!ALLOWED_JOBS.has(job)) {
    console.error(`Job no soportado: ${job}`);
    process.exit(1);
  }

  const secret = emailConfig.cronSecret;
  if (!secret) {
    console.error('EMAIL_CRON_SECRET vacío en el env activo');
    process.exit(1);
  }

  if (!canUseSupabaseEmailFunctions()) {
    console.error('Faltan SUPABASE_ANON_KEY / SUPABASE_PROJECT_REF — npm run configure:supabase-keys');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  await triggerEdgeJob(baseUrl, anonKey, secret, job);
  console.log('smoke-cron OK (Edge)');
}

main().catch((error) => {
  console.error('smoke-cron falló:', error);
  process.exit(1);
});
