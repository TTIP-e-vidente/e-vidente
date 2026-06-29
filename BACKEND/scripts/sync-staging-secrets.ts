/**
 * Copia secrets de BACKEND/.env → .env.staging solo si faltan en staging.
 * No imprime valores sensibles.
 *
 * Uso: npm run sync:staging-secrets
 */
import fs from 'fs';
import path from 'path';
import { BACKEND_ROOT } from './lib/postgres-env';

const LOCAL_ENV = path.resolve(BACKEND_ROOT, '.env');
const STAGING_ENV = path.resolve(BACKEND_ROOT, '.env.staging');

/** Vars que suelen vivir en .env local y deben replicarse a staging. */
const SYNC_KEYS = [
  'EMAIL_ENABLED',
  'BREVO_API_KEY',
  'BREVO_SENDER_EMAIL',
  'BREVO_SENDER_NAME',
  'BREVO_WEBHOOK_SECRET',
  'EMAIL_CRON_SECRET',
  'BACKEND_BASE_URL',
] as const;

function parseEnvMap(content: string): Map<string, string> {
  const map = new Map<string, string>();
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }
    const eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    map.set(key, value);
  }
  return map;
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
  if (!fs.existsSync(LOCAL_ENV)) {
    console.error('[sync:staging-secrets] No existe BACKEND/.env');
    process.exit(1);
  }
  if (!fs.existsSync(STAGING_ENV)) {
    console.error('[sync:staging-secrets] No existe BACKEND/.env.staging — corré npm run supabase:init');
    process.exit(1);
  }

  const local = parseEnvMap(fs.readFileSync(LOCAL_ENV, 'utf8'));
  let stagingContent = fs.readFileSync(STAGING_ENV, 'utf8');
  const staging = parseEnvMap(stagingContent);

  let changed = 0;
  for (const key of SYNC_KEYS) {
    const localValue = local.get(key)?.trim() ?? '';
    const stagingValue = staging.get(key)?.trim() ?? '';
    if (!localValue) {
      console.log(`[sync:staging-secrets] SKIP ${key} — no está en .env`);
      continue;
    }
    if (stagingValue) {
      console.log(`[sync:staging-secrets] OK ${key} — ya en .env.staging`);
      continue;
    }
    stagingContent = upsertEnvLine(stagingContent, key, localValue);
    changed += 1;
    console.log(`[sync:staging-secrets] COPY ${key} — .env → .env.staging`);
  }

  if (changed === 0) {
    console.log('[sync:staging-secrets] Nada que copiar');
    return;
  }

  fs.writeFileSync(STAGING_ENV, stagingContent.endsWith('\n') ? stagingContent : `${stagingContent}\n`, 'utf8');
  console.log(`[sync:staging-secrets] Listo — ${changed} variable(s) actualizada(s)`);
}

main();
