/**
 * Verificación sin dudas: panel + Edge + Brevo + OTP + todos los crons + schema.
 *
 * Uso: npm run verify:integration:full
 */
import { execSync } from 'child_process';
import path from 'path';

const BACKEND_ROOT = path.resolve(__dirname, '..');

const CRON_JOBS = [
  'outbound-emails',
  'streak-at-risk-emails',
  'streak-lost-emails',
  'retry-failed-emails',
  'refresh-leaderboard',
  'streak-emails',
] as const;

function run(label: string, command: string): void {
  console.log(`\n▶ ${label}`);
  execSync(command, {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: {
      ...process.env,
      ENV_FILE: process.env.ENV_FILE?.trim() || '.env.staging',
      VERIFY_INTEGRATION_STRICT: '1',
    },
  });
}

console.log('═══════════════════════════════════════════');
console.log('  E-VIDENTE — verify:integration:full');
console.log('  (sin dudas: Supabase + mails + crons + juego)');
console.log('═══════════════════════════════════════════');

run('Panel integración (strict)', 'npx ts-node scripts/integration-status.ts --strict');
run('Edge Functions guards', 'npx ts-node scripts/check-edge-functions.ts');
run('Brevo / verify-email-health', 'npx ts-node scripts/smoke-brevo-edge.ts');
run('OTP verify-email-request (Edge)', 'npx ts-node scripts/smoke-verify-email-edge.ts');
run('Auth / progress / avatar / leaderboard', 'npx ts-node scripts/smoke-edge-staging.ts');

for (const job of CRON_JOBS) {
  run(`Cron internal-job → ${job}`, `npx ts-node scripts/smoke-cron.ts ${job}`);
}

run('Schema + RLS + migraciones', 'npx ts-node scripts/verify-supabase.ts');

console.log('\n═══════════════════════════════════════════');
console.log('  verify:integration:full OK');
console.log('═══════════════════════════════════════════');
console.log('  Supabase Edge: login, progreso, avatar, ranking');
console.log('  Mails: Brevo + OTP + jobs de racha/retry/outbound');
console.log('  Godot: api_mode=supabase_edge (npm run sync:godot-config:staging)');
console.log('  Opcional inbox real:');
console.log('    SMOKE_EMAIL_TO=tu@mail.com npm run smoke:verify-email-edge -- --send');
console.log('');
