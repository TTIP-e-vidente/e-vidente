import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { connectSupabase, loadPostgresEnv } from './lib/postgres-env';
import { fetchRemoteHealth, isLocalBackendUrl, resolvePublicBackendUrl } from './lib/cloud-backend-url';
import { printDevReadyBanner } from './print-dev-ready';

const PROJECT_ROOT = path.resolve(__dirname, '..');
const STAGING_ENV = '.env.staging';

async function main(): Promise<void> {
  const staging = loadPostgresEnv('staging');
  const publicUrl = resolvePublicBackendUrl();
  const cloudMode = !isLocalBackendUrl(publicUrl);

  console.log('[dev] Modo Supabase (staging) — Express → pooler remoto\n');

  execSync('npx ts-node scripts/sync-staging-secrets.ts', {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
  });

  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true });

  if (fs.existsSync(path.resolve(PROJECT_ROOT, '.env.supabase-keys.local'))) {
    execSync('npx ts-node scripts/configure-supabase-api-keys.ts', {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      env: { ...process.env, ENV_FILE: STAGING_ENV },
    });
  }

  execSync('npx ts-node scripts/sync-godot-backend-config.ts', {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: STAGING_ENV },
  });

  if (cloudMode) {
    console.log(`\n[dev] BACKEND_BASE_URL cloud: ${publicUrl}`);
    const health = await fetchRemoteHealth(publicUrl);
    if (health.ok) {
      console.log('[dev] API en la nube OK — no se levanta servidor local.');
      console.log('[dev] Mails y jobs corren en Render + pg_cron Supabase.\n');
      process.env.ENV_FILE = STAGING_ENV;
      await printDevReadyBanner(publicUrl);
      return;
    }
    console.warn('[dev] La URL cloud no responde. Caída a servidor local...\n');
  }

  execSync('npx ts-node scripts/start-dev-if-needed.ts', {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: STAGING_ENV },
  });

  process.env.ENV_FILE = STAGING_ENV;
  await printDevReadyBanner();
}

main().catch((error) => {
  console.error('[dev:staging] falló:', error);
  process.exit(1);
});
