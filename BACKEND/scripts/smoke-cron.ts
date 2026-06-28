/**
 * Prueba que el endpoint de cron del backend responda con el secret configurado.
 *
 * Uso:
 *   npm run smoke:cron:staging
 *   npx ts-node scripts/smoke-cron.ts https://api.example.com streak-emails
 */
import { loadBackendEnv } from './lib/postgres-env';
import { emailConfig } from '../src/modules/email/email.config';

const ALLOWED_JOBS = new Set(['streak-emails', 'retry-failed-emails', 'outbound-emails']);

async function main(): Promise<void> {
  loadBackendEnv();

  const baseUrl = (process.argv[2] ?? process.env.BACKEND_BASE_URL ?? '').replace(/\/+$/, '');
  const job = process.argv[3] ?? 'outbound-emails';

  if (!baseUrl) {
    console.error('Uso: smoke-cron.ts <BACKEND_BASE_URL> [job]');
    process.exit(1);
  }

  if (!ALLOWED_JOBS.has(job)) {
    console.error(`Job no soportado: ${job}`);
    process.exit(1);
  }

  const secret = emailConfig.cronSecret;
  if (!secret) {
    console.error('EMAIL_CRON_SECRET vacío en el env activo');
    process.exit(1);
  }

  const url = `${baseUrl}/internal/jobs/${job}`;
  console.log(`POST ${url}`);

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Job-Secret': secret,
    },
  });

  const text = await response.text();
  console.log(`HTTP ${response.status}`);
  console.log(text);

  if (response.status < 200 || response.status >= 300) {
    process.exit(1);
  }

  console.log('smoke-cron OK');
}

main().catch((error) => {
  console.error('smoke-cron falló:', error);
  process.exit(1);
});
