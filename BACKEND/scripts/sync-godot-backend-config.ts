import fs from 'fs';
import path from 'path';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';
import { loadBackendEnv } from './lib/postgres-env';

loadBackendEnv();

const port = process.env.BACKEND_PORT ?? '3010';
const host = (process.env.BACKEND_HOST ?? 'localhost').trim();
const baseUrl = `http://${host}:${port}`;
const envFile = process.env.ENV_FILE?.trim() || '.env';
const emailEnabled = ['true', '1', 'yes'].includes(
  (process.env.EMAIL_ENABLED ?? '').trim().toLowerCase()
);

const targetPath = path.resolve(__dirname, '../../juego/config/backend.local.json');

const payload = {
  base_url: baseUrl,
  env_file: envFile,
  db: isRemotePostgres() ? 'supabase' : 'local',
  email_enabled: emailEnabled,
  synced_at: new Date().toISOString(),
};

fs.mkdirSync(path.dirname(targetPath), { recursive: true });
fs.writeFileSync(targetPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');

console.log(
  `[sync] Godot → ${baseUrl} · ${payload.db}${emailEnabled ? ' · brevo' : ''} (${path.relative(process.cwd(), targetPath)})`
);
