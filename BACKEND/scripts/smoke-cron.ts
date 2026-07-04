/**
 * Prueba internal-job en Supabase Edge (mismo camino que pg_cron).
 *
 * Uso:
 *   npm run smoke:cron:staging
 *   npm run smoke:cron:staging -- streak-at-risk-emails
 */
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import { ALL_INTERNAL_JOBS, assertInternalJobEnv, triggerInternalJob } from './lib/internal-job-client';

async function main(): Promise<void> {
  loadStagingWithKeys();

  const job = process.argv[2] ?? 'outbound-emails';
  if (!ALL_INTERNAL_JOBS.has(job)) {
    console.error(`Job no soportado: ${job}`);
    process.exit(1);
  }

  assertInternalJobEnv();
  console.log(`POST internal-job (job=${job})`);
  const result = await triggerInternalJob(job);
  console.log(`HTTP ${result.status}`);
  console.log(result.body);
  if (result.status < 200 || result.status >= 300) {
    process.exit(1);
  }
  console.log('smoke-cron OK (Edge)');
}

main().catch((error) => {
  console.error('smoke-cron falló:', error);
  process.exit(1);
});
