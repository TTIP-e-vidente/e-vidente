import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const backendRoot = path.resolve(__dirname, '..');

const integrationTests = [
  'tests/public-tables.unit.test.ts',
  'tests/supabase-env.unit.test.ts',
  'tests/supabase-env-password.unit.test.ts',
  'tests/supabase-connect.unit.test.ts',
  'tests/godot-backend-config.unit.test.ts',
  'tests/postgres.integration.test.ts',
  'tests/email.templates.unit.test.ts',
  'tests/email.jobs.integration.test.ts',
  'tests/email.webhook.integration.test.ts',
  'tests/email.internal.integration.test.ts',
  'tests/auth.integration.test.ts',
  'tests/player_authenticated.integration.test.ts',
  'tests/profile-mail-verification.integration.test.ts'
];

const smokeScripts = [
  'scripts/smoke-email-verification.ts'
];

/**
 * Smokes de Edge Functions — se ejecutan cuando el staging está configurado
 * (SUPABASE_ANON_KEY y SUPABASE_PROJECT_REF disponibles).
 * Cubren el flujo completo de registro + login + progreso + verificación OTP
 * sobre Supabase real, complementando los tests Express/local de arriba.
 */
const edgeSmokeScripts = [
  'scripts/smoke-auth-edge.ts',
  'scripts/smoke-verify-email-edge.ts',
  'scripts/smoke-brevo-edge.ts',
];

function hasSupabaseConfig(): boolean {
  const anonKey = process.env.SUPABASE_ANON_KEY?.trim() ?? '';
  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim() ?? '';
  return anonKey.length > 0 && projectRef.length > 0 && !projectRef.includes('TU_');
}

function loadStagingEnvIfNeeded(): boolean {
  if (hasSupabaseConfig()) {
    return true;
  }
  const stagingEnv = path.join(backendRoot, '.env.staging');
  if (!fs.existsSync(stagingEnv)) {
    return false;
  }
  const lines = fs.readFileSync(stagingEnv, 'utf8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx < 0) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim().replace(/^"(.*)"$/, '$1');
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
  return hasSupabaseConfig();
}

function runIntegrationTests(): void {
  const env: NodeJS.ProcessEnv = {
    ...process.env,
    NODE_ENV: 'test',
    EMAIL_ENABLED: 'false',
    EMAIL_CRON_SECRET: process.env.EMAIL_CRON_SECRET ?? 'evidente_email_cron_test_secret'
  };

  for (const relativeTestPath of integrationTests) {
    const testPath = path.join(backendRoot, relativeTestPath);
    console.log(`\n> ts-node ${relativeTestPath}`);
    execSync(`npx ts-node "${testPath}"`, {
      cwd: backendRoot,
      env,
      stdio: 'inherit'
    });
  }

  for (const relativeScriptPath of smokeScripts) {
    console.log(`\n> ts-node ${relativeScriptPath}`);
    execSync(`npx ts-node "${path.join(backendRoot, relativeScriptPath)}"`, {
      cwd: backendRoot,
      env,
      stdio: 'inherit'
    });
  }

  // Smokes Edge Functions — solo si hay config de Supabase disponible
  const supabaseAvailable = loadStagingEnvIfNeeded();
  if (!supabaseAvailable) {
    console.log('\n[edge-smokes] SKIP — SUPABASE_ANON_KEY no configurada (solo local)');
    return;
  }

  console.log('\n[edge-smokes] Supabase configurado — ejecutando smokes Edge Functions');
  const edgeEnv: NodeJS.ProcessEnv = { ...process.env, NODE_ENV: 'test' };

  for (const relativeScriptPath of edgeSmokeScripts) {
    console.log(`\n> ts-node ${relativeScriptPath}`);
    execSync(`npx ts-node "${path.join(backendRoot, relativeScriptPath)}"`, {
      cwd: backendRoot,
      env: edgeEnv,
      stdio: 'inherit'
    });
  }
}

runIntegrationTests();
