/**
 * Guía para deploy manual cuando la CLI no tiene permisos (cuenta/org distinta).
 * Uso: npm run supabase:functions:dashboard-guide
 */
import {
  buildEdgeFunctionSecrets,
  validateEdgeFunctionSecrets,
} from './lib/supabase-edge-secrets';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import { resolveSupabaseFunctionsUrl } from './lib/supabase-functions-env';

const FUNCTIONS = [
  'verify-email-request',
  'verify-email-confirm',
  'verify-email-health',
  'internal-job',
];

async function main(): Promise<void> {
  loadStagingWithKeys();
  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim() ?? 'kpvjdzdynqfhqfiatwqz';
  const secrets = buildEdgeFunctionSecrets();
  const missing = validateEdgeFunctionSecrets(secrets);

  console.log('═══════════════════════════════════════════');
  console.log('  Deploy manual — Edge Functions EVIDENTE');
  console.log('═══════════════════════════════════════════\n');

  if (missing.length > 0) {
    console.error('Faltan valores en .env.staging:', missing.join(', '));
    process.exit(1);
  }

  console.log('PASO 1 — Secrets en el dashboard');
  console.log('  https://supabase.com/dashboard/project/%s/functions/secrets\n', projectRef);
  for (const [key, value] of Object.entries(secrets)) {
    const masked =
      key.includes('SECRET') || key.includes('KEY') || key.includes('PASSWORD')
        ? `${value.slice(0, 4)}…${value.slice(-4)} (${value.length} chars)`
        : value;
    console.log(`  ${key}=${masked}`);
  }

  console.log('\nPASO 2 — Login CLI con la cuenta del dashboard EVIDENTE');
  console.log('  cd BACKEND');
  console.log('  npx supabase logout');
  console.log('  npx supabase login');
  console.log('  npm run supabase:cli-check   # debe listar EVIDENTE o validar token sbp_*\n');

  console.log('PASO 3 — Deploy desde la raíz del repo (carpeta e-vidente)');
  for (const name of FUNCTIONS) {
    console.log(
      `  npx supabase functions deploy ${name} --project-ref ${projectRef} --no-verify-jwt`,
    );
  }

  console.log('\nPASO 4 — Verificar');
  console.log('  cd BACKEND');
  console.log('  npm run check:edge:staging');
  console.log('  npm run integrate:status\n');

  console.log('URL functions:', resolveSupabaseFunctionsUrl(projectRef));
  console.log('\nNota: SUPABASE_ACCESS_TOKEN debe ser sbp_* de Account → Access Tokens,');
  console.log('      NO sb_secret_* ni anon JWT.\n');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
