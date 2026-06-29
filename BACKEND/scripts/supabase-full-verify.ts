/**
 * Verificación integral legacy — preferí npm run verify:integration:full
 * Uso: npm run supabase:full-verify
 */
import { execSync } from 'child_process';
import path from 'path';

const BACKEND_ROOT = path.resolve(__dirname, '..');

function run(label: string, command: string): void {
  console.log(`\n▶ ${label}`);
  execSync(command, {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: '.env.staging' },
  });
}

console.log('═══════════════════════════════════════════');
console.log('  E-VIDENTE — Supabase full verify');
console.log('  (alias → verify:integration:full)');
console.log('═══════════════════════════════════════════');

run('Verificación integral', 'npm run verify:integration:full');

console.log('\n═══════════════════════════════════════════');
console.log('  Supabase full verify OK');
console.log('═══════════════════════════════════════════');
