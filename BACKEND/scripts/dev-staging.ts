import { execSync } from 'child_process';
import path from 'path';
import { connectSupabase, loadPostgresEnv } from './lib/postgres-env';

const PROJECT_ROOT = path.resolve(__dirname, '..');
const STAGING_ENV = '.env.staging';

async function main(): Promise<void> {
  const staging = loadPostgresEnv('staging');

  console.log('[dev:staging] Conectando a Supabase…');
  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true });

  execSync('npx ts-node scripts/sync-godot-backend-config.ts', {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: STAGING_ENV },
  });

  execSync('npx ts-node scripts/start-dev-if-needed.ts', {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: STAGING_ENV },
  });
}

main().catch((error) => {
  console.error('[dev:staging] falló:', error);
  process.exit(1);
});
