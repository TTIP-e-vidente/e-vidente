/**
 * Verificación end-to-end de staging Supabase (env + schema + API + email opcional).
 *
 * Uso:
 *   npm run staging:verify
 *   npm run staging:verify -- --email
 *   npm run staging:verify -- --skip-smoke
 */
import { execSync } from 'child_process';
import path from 'path';
import { loadPostgresEnv } from './lib/postgres-env';

const PROJECT_ROOT = path.resolve(__dirname, '..');

function isBrevoConfigured(): boolean {
  const enabled = (process.env.EMAIL_ENABLED ?? '').trim().toLowerCase();
  if (enabled !== 'true' && enabled !== '1' && enabled !== 'yes') {
    return false;
  }
  return Boolean(process.env.BREVO_API_KEY?.trim() && process.env.BREVO_SENDER_EMAIL?.trim());
}

interface Step {
  id: string;
  command: string;
  optional?: boolean;
}

function runStep(step: Step): void {
  console.log(`\n── ${step.id} ──\n`);
  execSync(step.command, { cwd: PROJECT_ROOT, stdio: 'inherit' });
}

function main(): void {
  const forceEmail = process.argv.includes('--email');
  const skipSmoke = process.argv.includes('--skip-smoke');

  loadPostgresEnv('staging');

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Staging verify');
  console.log('═══════════════════════════════════════════');

  const steps: Step[] = [
    { id: 'supabase:status', command: 'npm run supabase:status' },
    { id: 'check:deploy:staging', command: 'npm run check:deploy:staging' },
    { id: 'verify:supabase', command: 'npm run verify:supabase' },
    { id: 'setup:supabase:cron', command: 'npm run setup:supabase:cron' },
  ];

  if (!skipSmoke) {
    steps.push({ id: 'smoke:staging', command: 'npm run smoke:staging' });
  }

  const brevoReady = isBrevoConfigured();
  if (forceEmail && !brevoReady) {
    console.error(
      '\n[staging:verify] --email requiere EMAIL_ENABLED=true, BREVO_API_KEY y BREVO_SENDER_EMAIL en .env.staging'
    );
    process.exit(1);
  }

  if (forceEmail || brevoReady) {
    steps.push({
      id: 'smoke:email:staging',
      command: 'npm run smoke:email:staging',
      optional: !forceEmail,
    });
  } else {
    console.log(
      '\n[staging:verify] Email: SKIP — activá Brevo en .env.staging o usá --email cuando esté listo'
    );
  }

  for (const step of steps) {
    try {
      runStep(step);
    } catch {
      if (step.optional) {
        console.warn(`\n[staging:verify] WARN — ${step.id} falló (opcional)`);
        continue;
      }
      console.error(`\n[staging:verify] FAIL en ${step.id}`);
      process.exit(1);
    }
  }

  console.log('\n═══════════════════════════════════════════');
  console.log('  Staging verify OK');
  console.log('  Siguiente: npm run dev');
  console.log('═══════════════════════════════════════════\n');
}

main();
