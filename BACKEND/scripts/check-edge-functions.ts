/**
 * Verifica Edge Functions desplegadas (verify + internal-job).
 * Uso: npm run check:edge:staging
 */
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';
import { loadStagingWithKeys } from './lib/supabase-keys-local';

type JsonObject = Record<string, unknown>;

async function fetchJson(
  url: string,
  options: RequestInit = {},
): Promise<{ status: number; body: JsonObject }> {
  const response = await fetch(url, options);
  const text = await response.text();
  return {
    status: response.status,
    body: text ? (JSON.parse(text) as JsonObject) : {},
  };
}

async function main(): Promise<void> {
  loadStagingWithKeys();

  console.log('═══════════════════════════════════════════');
  console.log('  Edge Functions — health check');
  console.log('═══════════════════════════════════════════\n');

  if (!canUseSupabaseEmailFunctions()) {
    console.error('FAIL — Falta SUPABASE_ANON_KEY o SUPABASE_PROJECT_REF');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const cronSecret = process.env.EMAIL_CRON_SECRET?.trim() ?? '';
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
  };

  let failed = false;

  const health = await fetchJson(`${baseUrl}/verify-email-health`, {
    method: 'GET',
    headers,
  });
  if (health.status === 200 && health.body.ok === true) {
    console.log('OK  verify-email-health');
    console.log(`    delivery_configured=${health.body.delivery_configured}`);
  } else {
    console.error(`FAIL verify-email-health HTTP ${health.status}`);
    failed = true;
  }

  const authHealth = await fetchJson(`${baseUrl}/auth-health`, {
    method: 'GET',
    headers,
  });
  if (authHealth.status === 200 && authHealth.body.status === 'ok') {
    const migrations = authHealth.body.migrations as JsonObject | undefined;
    const migrationsHealthy = migrations?.healthy === true;
    const expectedOk = migrations?.expected === 36;
    if (migrationsHealthy && expectedOk) {
      console.log('OK  auth-health');
      console.log(`    migrations=${migrations?.applied}/${migrations?.expected}`);
    } else {
      console.error(
        `FAIL auth-health migrations unhealthy (${JSON.stringify(migrations)}) — redeploy auth-health`,
      );
      failed = true;
    }
  } else {
    console.error(`FAIL auth-health HTTP ${authHealth.status}`);
    failed = true;
  }

  const badAuth = await fetchJson(`${baseUrl}/verify-email-request`, {
    method: 'POST',
    headers: { ...headers, Authorization: 'Bearer invalid' },
    body: JSON.stringify({}),
  });
  if (badAuth.status === 401) {
    console.log('OK  verify-email-request rechaza JWT inválido');
  } else {
    console.error(`FAIL verify-email-request auth guard HTTP ${badAuth.status}`);
    failed = true;
  }

  const jobNoSecret = await fetchJson(`${baseUrl}/internal-job`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ job: 'streak-emails' }),
  });
  if (jobNoSecret.status === 401) {
    console.log('OK  internal-job rechaza sin X-Job-Secret');
  } else if (jobNoSecret.status === 404) {
    console.error('FAIL internal-job no desplegada (404)');
    failed = true;
  } else {
    console.error(`WARN internal-job sin secret → HTTP ${jobNoSecret.status} (esperado 401)`);
  }

  if (cronSecret.length >= 12) {
    const jobDry = await fetchJson(`${baseUrl}/internal-job`, {
      method: 'POST',
      headers: {
        ...headers,
        'X-Job-Secret': cronSecret,
      },
      body: JSON.stringify({ job: 'unknown-job' }),
    });
    if (jobDry.status === 400) {
      console.log('OK  internal-job responde con secret (job desconocido → 400)');
    } else if (jobDry.status === 401) {
      console.error('FAIL internal-job secret no coincide con EMAIL_CRON_SECRET en Supabase');
      failed = true;
    } else if (jobDry.status === 200 || jobDry.status === 503) {
      console.log('OK  internal-job desplegada y autorizada');
    }
  } else {
    console.log('SKIP internal-job con secret (EMAIL_CRON_SECRET corto en env local)');
  }

  console.log(`\nURL: ${baseUrl}`);

  if (failed) {
    console.error('\nEdge Functions check FAIL → npm run supabase:functions:deploy');
    process.exit(1);
  }

  console.log('\nEdge Functions check OK.');
}

main().catch((error) => {
  console.error('\nEdge check falló:', error);
  process.exit(1);
});
