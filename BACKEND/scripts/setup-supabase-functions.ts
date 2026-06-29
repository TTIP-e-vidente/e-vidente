/**
 * Despliega Edge Functions de verificación de email en Supabase.
 *
 * Requiere: supabase CLI (`npx supabase`), login y link al proyecto.
 *
 * Uso:
 *   npm run supabase:functions:deploy
 *   npm run supabase:functions:deploy -- --secrets-only
 */
import fs from 'fs';
import path from 'path';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';
import {
  BACKEND_ROOT,
  loadBackendEnv,
  assertSupabaseStagingEnv,
} from './lib/postgres-env';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';
import {
  buildEdgeFunctionSecrets,
  validateEdgeFunctionSecrets,
} from './lib/supabase-edge-secrets';
import {
  linkSupabaseProject,
  printCliAccessHint,
  resolveCliProjectAccess,
  runSupabaseCli,
  verifySupabaseCliProjectAccess,
} from './lib/supabase-cli-access';
import { assertManagementProjectAccess } from './lib/supabase-management-api';
import { hasSupabaseAccessToken, loadStagingWithKeys } from './lib/supabase-keys-local';

const REPO_ROOT = path.resolve(BACKEND_ROOT, '..');
const SUPABASE_DIR = path.join(REPO_ROOT, 'supabase');

function run(command: string, cwd = REPO_ROOT): void {
  runSupabaseCli(command, cwd);
}

function setSecrets(projectRef: string): void {
  const secrets = buildEdgeFunctionSecrets();
  const missing = validateEdgeFunctionSecrets(secrets);

  if (missing.length > 0) {
    throw new Error(
      `Faltan secrets para Edge Functions: ${missing.join(', ')}. Completá BACKEND/.env.staging`,
    );
  }

  const envFilePath = path.join(SUPABASE_DIR, '.secrets.tmp');
  const lines = Object.entries(secrets).map(([key, value]) => `${key}=${value}`);
  fs.writeFileSync(envFilePath, `${lines.join('\n')}\n`, 'utf8');

  console.log('\n▶ Subiendo secrets a Supabase (archivo temporal, no commitear)...');
  try {
    run(`npx supabase secrets set --env-file "${envFilePath}" --project-ref ${projectRef}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (message.includes('necessary privileges') || message.includes('access-control')) {
      console.error('\n✗ Sin permisos de Management API para secrets/deploy.');
      console.error('  Corré: npm run supabase:functions:dashboard-guide');
      console.error('  O generá Access Token sbp_* desde la cuenta del dashboard EVIDENTE.\n');
    }
    throw error;
  } finally {
    fs.unlinkSync(envFilePath);
  }
}

function deployFunctions(projectRef: string): void {
  const functions = [
    'verify-email-request',
    'verify-email-confirm',
    'verify-email-health',
    'brevo-webhook',
    'internal-job',
    'auth-login',
    'auth-register',
    'auth-me',
    'auth-health',
    'player-me',
    'player-email-status',
    'player-progress-get',
    'player-progress-save',
    'player-progress-batch',
    'player-progress-reset',
    'avatar-upload',
    'avatar-get',
    'avatar-delete',
    'avatar-public',
    'leaderboard-list',
    'leaderboard-meta',
    'leaderboard-me',
    'leaderboard-me-summary',
  ];

  console.log('\n▶ Desplegando Edge Functions...');
  for (const name of functions) {
    console.log(`  • ${name}`);
    run(
      `npx supabase functions deploy ${name} --project-ref ${projectRef} --no-verify-jwt`,
    );
  }
}

async function main(): Promise<void> {
  const secretsOnly = process.argv.includes('--secrets-only');
  const skipCliCheck = process.argv.includes('--skip-cli-check');
  loadStagingWithKeys();
  const loaded = loadBackendEnv();
  assertSupabaseStagingEnv(path.resolve(BACKEND_ROOT, loaded.envFile));

  if (!isRemotePostgres()) {
    throw new Error('Edge Functions de email requieren Supabase (POSTGRES_SSL=true).');
  }

  if (!fs.existsSync(SUPABASE_DIR)) {
    throw new Error(`No existe ${SUPABASE_DIR}`);
  }

  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim();
  if (!projectRef) {
    throw new Error('Falta SUPABASE_PROJECT_REF en .env.staging');
  }

  if (!skipCliCheck) {
    if (hasSupabaseAccessToken()) {
      const project = await assertManagementProjectAccess(projectRef);
      console.log(`\n▶ Management API OK — ${project.name} (${project.ref})`);
    } else {
      const access = resolveCliProjectAccess(projectRef);
      if (access.mode === 'none') {
        verifySupabaseCliProjectAccess(projectRef);
      }
      printCliAccessHint(access, projectRef);
      try {
        linkSupabaseProject(projectRef, REPO_ROOT);
      } catch {
        console.log('  (link omitido)');
      }
    }
  } else {
    console.warn('\nWARN: --skip-cli-check activo (solo si ya validaste acceso)\n');
  }

  if (!canUseSupabaseEmailFunctions()) {
    console.warn(
      '\nWARN: Falta SUPABASE_ANON_KEY — Godot no podrá llamar Edge Functions hasta agregarlo.',
    );
    console.warn('  Dashboard → Project Settings → API → anon public key');
    console.warn('  Agregá SUPABASE_ANON_KEY=... en BACKEND/.env.staging\n');
  }

  setSecrets(projectRef);

  if (!secretsOnly) {
    deployFunctions(projectRef);
  }

  const functionsUrl = resolveSupabaseFunctionsUrl(projectRef);
  console.log('\n✓ Edge Functions listas');
  console.log(`  URL base: ${functionsUrl}`);
  console.log('  Endpoints: verify-email-*, auth-*, internal-job (crons pg_cron)');
  console.log('\nPróximo paso: npm run setup:supabase:cron && npm run sync:godot-config');
}

main().catch((error) => {
  console.error('\nsupabase:functions:deploy falló:', error);
  console.error('\nSi falta CLI: npx supabase login && npx supabase link --project-ref <ref>');
  process.exit(1);
});
