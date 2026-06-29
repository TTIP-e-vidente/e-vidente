/**
 * Escribe claves Supabase API en .env.staging (gitignored).
 * NO commitear secrets. Pasar por entorno, no hardcodear acá.
 *
 * PowerShell:
 *   $env:SUPABASE_ANON_KEY="eyJ..."
 *   $env:SUPABASE_SERVICE_ROLE_KEY="eyJ..."   # opcional, solo backend/scripts
 *   npm run configure:supabase-keys
 */
import fs from 'fs';
import path from 'path';
import { BACKEND_ROOT } from './lib/postgres-env';
import { loadStagingWithKeys } from './lib/supabase-keys-local';

const STAGING_PATH = path.resolve(BACKEND_ROOT, '.env.staging');
const KEYS_LOCAL = path.resolve(BACKEND_ROOT, '.env.supabase-keys.local');

function loadKeysLocal(): void {
  loadStagingWithKeys();
  if (fs.existsSync(KEYS_LOCAL)) {
    console.log(`Keys desde ${path.basename(KEYS_LOCAL)}`);
  }
}

function upsertEnvLine(content: string, key: string, value: string): string {
  const lines = content.split(/\r?\n/);
  let found = false;
  const updated = lines.map((line) => {
    if (line.trimStart().startsWith(`${key}=`)) {
      found = true;
      return `${key}=${value}`;
    }
    return line;
  });
  if (!found) {
    updated.push(`${key}=${value}`);
  }
  return updated.join('\n');
}

function main(): void {
  loadKeysLocal();

  const anonKey = process.env.SUPABASE_ANON_KEY?.trim();
  const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim() || 'kpvjdzdynqfhqfiatwqz';
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY?.trim();
  const secretKey = process.env.SUPABASE_SECRET_KEY?.trim();
  const dbPassword = process.env.SUPABASE_DB_PASSWORD?.trim();
  const accessToken = process.env.SUPABASE_ACCESS_TOKEN?.trim();

  if (!anonKey) {
    console.error('ERROR: falta SUPABASE_ANON_KEY.');
    console.error('  Creá BACKEND/.env.supabase-keys.local (ver docs/env.supabase-keys.local.example)');
    console.error('  o pasala por entorno: $env:SUPABASE_ANON_KEY="eyJ..."');
    process.exit(1);
  }

  if (!fs.existsSync(STAGING_PATH)) {
    console.error(`ERROR: no existe ${STAGING_PATH}`);
    process.exit(1);
  }

  let content = fs.readFileSync(STAGING_PATH, 'utf8');
  content = upsertEnvLine(content, 'SUPABASE_PROJECT_REF', projectRef);
  content = upsertEnvLine(content, 'SUPABASE_URL', `https://${projectRef}.supabase.co`);
  content = upsertEnvLine(content, 'SUPABASE_ANON_KEY', anonKey);
  if (serviceRole) {
    content = upsertEnvLine(content, 'SUPABASE_SERVICE_ROLE_KEY', serviceRole);
  }
  if (publishableKey) {
    content = upsertEnvLine(content, 'SUPABASE_PUBLISHABLE_KEY', publishableKey);
  }
  if (secretKey) {
    content = upsertEnvLine(content, 'SUPABASE_SECRET_KEY', secretKey);
  }
  if (dbPassword) {
    const quoted =
      dbPassword.includes('#') ||
      dbPassword.includes(' ') ||
      dbPassword.includes('"')
        ? `"${dbPassword.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`
        : dbPassword;
    content = upsertEnvLine(content, 'POSTGRES_PASSWORD', quoted);
  }
  if (accessToken) {
    content = upsertEnvLine(content, 'SUPABASE_ACCESS_TOKEN', accessToken);
  }

  if (!content.endsWith('\n')) {
    content = `${content}\n`;
  }
  fs.writeFileSync(STAGING_PATH, content, 'utf8');
  console.log('✓ .env.staging actualizado: SUPABASE_PROJECT_REF, SUPABASE_URL, SUPABASE_ANON_KEY');
  if (serviceRole) {
    console.log('✓ SUPABASE_SERVICE_ROLE_KEY (solo scripts/deploy, no Godot)');
  }
  if (publishableKey) {
    console.log('✓ SUPABASE_PUBLISHABLE_KEY (formato nuevo sb_publishable_*)');
  }
  if (dbPassword) {
    console.log('✓ POSTGRES_PASSWORD actualizado desde SUPABASE_DB_PASSWORD');
  }
  if (accessToken) {
    console.log('✓ SUPABASE_ACCESS_TOKEN (deploy sin login interactivo)');
  }
  console.log('\nSiguiente: npm run sync:godot-config:staging && npm run supabase:cli-check');
}

main();
