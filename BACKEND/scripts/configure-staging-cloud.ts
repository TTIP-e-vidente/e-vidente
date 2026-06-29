/**
 * Apunta staging completo a un backend público (Render, etc.) — sin terminal local.
 *
 * Uso:
 *   npm run staging:cloud -- https://e-vidente-api.onrender.com
 */
import fs from 'fs';
import { execSync } from 'child_process';
import path from 'path';
import {
  BACKEND_ROOT,
  assertSupabaseStagingEnv,
  loadPostgresEnv,
} from './lib/postgres-env';
import { fetchRemoteHealth, isLocalBackendUrl } from './lib/cloud-backend-url';

const STAGING_ENV = '.env.staging';

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

async function main(): Promise<void> {
  const rawUrl = process.argv[2]?.trim() ?? '';
  if (!rawUrl) {
    console.error('Uso: npm run staging:cloud -- https://tu-api.onrender.com');
    process.exit(1);
  }
  const baseUrl = rawUrl.replace(/\/+$/, '');
  if (isLocalBackendUrl(baseUrl)) {
    console.error('La URL debe ser pública (https://...). localhost no sirve para modo sin terminal.');
    process.exit(1);
  }

  const staging = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(staging.envPath);

  console.log(`Verificando ${baseUrl}/health/db ...`);
  const health = await fetchRemoteHealth(baseUrl);
  if (!health.ok) {
    console.error('ERROR: el backend no responde. Deploye primero en Render y probá de nuevo.');
    process.exit(1);
  }

  let content = fs.readFileSync(staging.envPath, 'utf8');
  content = upsertEnvLine(content, 'BACKEND_BASE_URL', baseUrl);
  fs.writeFileSync(staging.envPath, content.endsWith('\n') ? content : `${content}\n`, 'utf8');
  process.env.BACKEND_BASE_URL = baseUrl;

  console.log(`BACKEND_BASE_URL → ${baseUrl} en ${STAGING_ENV}`);

  execSync('npm run setup:supabase:cron', {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: STAGING_ENV, BACKEND_BASE_URL: baseUrl },
  });

  execSync('npx ts-node scripts/sync-godot-backend-config.ts', {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: STAGING_ENV, BACKEND_BASE_URL: baseUrl },
  });

  console.log('\nModo cloud listo:');
  console.log('  • Godot → API en la nube (no hace falta npm run dev)');
  console.log('  • Supabase pg_cron → misma URL (mails de racha automáticos)');
  console.log('  • Verificación OTP → Brevo al tocar Verificar mail en el juego');
  if (health.remote) {
    const mig = health.migrations;
    console.log(
      `  • DB remota OK · migraciones ${mig?.applied ?? '?'}/${mig?.expected ?? '?'}`
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
