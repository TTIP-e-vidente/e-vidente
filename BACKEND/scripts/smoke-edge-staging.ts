/**
 * Ejecuta todos los smoke tests contra Supabase Edge (staging).
 * Uso: npm run smoke:edge:staging
 */
import { execSync } from 'child_process';
import path from 'path';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import { canUseSupabaseEmailFunctions } from './lib/supabase-functions-env';

const BACKEND_ROOT = path.resolve(__dirname, '..');

const STEPS = [
  'smoke-auth-edge.ts',
  'smoke-progress-edge.ts',
  'smoke-avatar-edge.ts',
  'smoke-leaderboard-edge.ts',
] as const;

function run(script: string): void {
  console.log(`\n▶ ${script}`);
  execSync(`npx ts-node scripts/${script}`, {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: process.env,
  });
}

function main(): void {
  loadStagingWithKeys();
  if (!canUseSupabaseEmailFunctions()) {
    console.error('[smoke:edge:staging] FAIL — configurá SUPABASE_PROJECT_REF y keys');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════');
  console.log('  Smoke Supabase Edge (staging)');
  console.log('═══════════════════════════════════════════');

  for (const step of STEPS) {
    run(step);
  }

  console.log('\n[smoke:edge:staging] OK — todos los smokes Edge pasaron');
}

main();
