/**
 * Bootstrap producción: migraciones, Edge Functions, pg_cron, Godot.
 *
 * Uso:
 *   cp .env.production.example .env.production   # completar secrets
 *   npm run prod:bootstrap
 */
import { execSync } from 'child_process';
import { BACKEND_ROOT, loadBackendEnv } from './lib/postgres-env';
import { resolveSupabaseFunctionsUrl } from './lib/supabase-functions-env';

const ENV_FILE = process.env.ENV_FILE?.trim() || '.env.production';

function run(label: string, command: string, optional = false): void {
  console.log(`\n▶ ${label}`);
  try {
    execSync(command, {
      cwd: BACKEND_ROOT,
      stdio: 'inherit',
      env: { ...process.env, ENV_FILE },
    });
  } catch {
    if (optional) {
      console.warn(`  (opcional falló: ${label})`);
      return;
    }
    throw new Error(label);
  }
}

function printPostBootstrapChecklist(functionsUrl: string): void {
  const ref = process.env.SUPABASE_PROJECT_REF?.trim() ?? '<ref>';
  console.log(`
═══════════════════════════════════════════
  Checklist manual post-bootstrap
═══════════════════════════════════════════

1. Supabase (${ref}):
   • Edge Functions → Logs (verify-email-*, internal-job)
   • SQL: SELECT * FROM private.cron_invocation_log ORDER BY created_at DESC LIMIT 10;
   • pg_cron: npm run setup:supabase:cron (con ENV_FILE=.env.production)

2. Brevo:
   • Sender verificado (dominio propio en prod)
   • Webhook → https://${ref}.supabase.co/functions/v1/brevo-webhook

3. Godot release:
   • ENV_FILE=.env.production npm run sync:godot-config
   • api_mode=supabase_edge en backend.local.json

4. Verificación:
   • ENV_FILE=.env.production npm run verify:integration:full
   • ENV_FILE=.env.production npm run check:edge

Edge URL: ${functionsUrl || '(configurar SUPABASE_PROJECT_REF)'}
`);
}

async function main(): Promise<void> {
  process.env.ENV_FILE = ENV_FILE;
  loadBackendEnv();

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Production bootstrap');
  console.log('═══════════════════════════════════════════');
  console.log(`Env: ${ENV_FILE}\n`);

  run('Deploy readiness', `npx ts-node scripts/check-deploy-readiness.ts --production`);
  run('Migraciones SQL', 'npx ts-node scripts/run-migrations.ts');
  run('Edge Functions deploy', 'npx ts-node scripts/setup-supabase-functions.ts');
  run('pg_cron → Edge', 'npx ts-node scripts/setup-supabase-cron.ts');
  run('Godot config sync', 'npx ts-node scripts/sync-godot-backend-config.ts');
  run('Edge health', 'npx ts-node scripts/check-edge-functions.ts');
  run('Schema verify', 'npx ts-node scripts/verify-supabase.ts', true);

  let functionsUrl = '';
  try {
    functionsUrl = resolveSupabaseFunctionsUrl();
  } catch {
    functionsUrl = '';
  }
  printPostBootstrapChecklist(functionsUrl);
  console.log('prod:bootstrap completado.');
}

main().catch((error) => {
  console.error('\nprod:bootstrap falló:', error);
  process.exit(1);
});
