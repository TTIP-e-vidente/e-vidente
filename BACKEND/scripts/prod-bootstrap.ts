/**
 * Bootstrap producción: migraciones, Edge Functions, crons, checks.
 *
 * Uso:
 *   cp .env.production.example .env.production   # completar secrets
 *   npm run prod:bootstrap
 */
import { execSync } from 'child_process';
import { BACKEND_ROOT, loadBackendEnv } from './lib/postgres-env';

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

function printPostBootstrapChecklist(publicUrl: string): void {
  console.log(`
═══════════════════════════════════════════
  Checklist manual post-bootstrap
═══════════════════════════════════════════

1. Render (o tu host):
   • Conectar repo → BACKEND/render.yaml
   • Secrets desde .env.production (JWT, DB, Brevo, EMAIL_CRON_SECRET)
   • BACKEND_BASE_URL=${publicUrl || 'https://TU-SERVICIO.onrender.com'}
   • Health: GET /health/ready → 200

2. Supabase Dashboard:
   • Edge Functions → Logs (verify-email-*, internal-job)
   • Authentication → desactivado (usamos JWT Express)
   • SQL: SELECT * FROM private.cron_invocation_log ORDER BY created_at DESC LIMIT 10;

3. Brevo:
   • Sender verificado (dominio propio en prod)
   • Webhook opcional → ${publicUrl || 'https://API'}/internal/jobs/brevo-webhook

4. Godot release:
   • npm run sync:godot-config (con ENV_FILE=.env.production)
   • Exportar con backend.local.json apuntando a API prod + email_via_supabase

5. Monitoreo:
   • npm run check:deploy:production
   • npm run check:edge:production
   • npm run verify:supabase (con .env.production)
`);
}

async function main(): Promise<void> {
  const envFile = process.env.ENV_FILE?.trim() || '.env.production';
  process.env.ENV_FILE = envFile;
  loadBackendEnv();

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Production bootstrap');
  console.log('═══════════════════════════════════════════');
  console.log(`Env: ${envFile}\n`);

  run('Deploy readiness', `npx ts-node scripts/check-deploy-readiness.ts --production`);
  run('Migraciones SQL', 'npx ts-node scripts/run-migrations.ts');
  run('Edge Functions deploy', 'npx ts-node scripts/setup-supabase-functions.ts', true);
  run('pg_cron → Edge Functions', 'npx ts-node scripts/setup-supabase-cron.ts');
  run('Godot config sync', 'npx ts-node scripts/sync-godot-backend-config.ts');
  run('Edge Functions smoke', 'npx ts-node scripts/check-edge-functions.ts', true);
  run('Schema verify', 'npx ts-node scripts/verify-supabase.ts', true);

  const publicUrl = (process.env.BACKEND_BASE_URL ?? '').trim().replace(/\/+$/, '');
  printPostBootstrapChecklist(publicUrl);
  console.log('prod:bootstrap completado.');
}

main().catch((error) => {
  console.error('\nprod:bootstrap falló:', error);
  process.exit(1);
});
