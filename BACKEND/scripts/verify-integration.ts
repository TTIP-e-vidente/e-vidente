/**
 * Verificación completa: panel de integración + smokes Edge (modo estricto).
 * Uso:
 *   npm run verify:integration          # panel integrate:status
 *   npm run verify:integration:strict   # panel + smoke:edge:staging
 */
import { execSync } from 'child_process';
import path from 'path';

const BACKEND_ROOT = path.resolve(__dirname, '..');
const strict =
  process.argv.includes('--strict') || process.env.VERIFY_INTEGRATION_STRICT === '1';

function run(script: string): void {
  execSync(`npx ts-node scripts/${script}`, {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: {
      ...process.env,
      ENV_FILE: process.env.ENV_FILE?.trim() || '.env.staging',
      VERIFY_INTEGRATION_STRICT: strict ? '1' : '0',
    },
  });
}

console.log('═══════════════════════════════════════════');
console.log(`  E-VIDENTE — verify:integration${strict ? ' (strict)' : ''}`);
console.log('═══════════════════════════════════════════\n');

run('integration-status.ts');

if (strict) {
  console.log('\n▶ Smoke Brevo (verify-email-health)\n');
  run('smoke-brevo-edge.ts');
  console.log('\n▶ Smoke Edge (auth/progress/avatar/leaderboard)\n');
  run('smoke-edge-staging.ts');
}

console.log('\nverify:integration OK.\n');
