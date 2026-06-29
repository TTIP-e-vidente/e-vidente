import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import { BACKEND_ROOT, loadPostgresEnv, type LoadedPostgresEnv } from './postgres-env';

const KEYS_LOCAL = path.resolve(BACKEND_ROOT, '.env.supabase-keys.local');

function loadEnvFileIntoProcess(envPath: string, override: boolean): void {
  if (!fs.existsSync(envPath)) {
    return;
  }
  let raw = fs.readFileSync(envPath, 'utf8');
  if (raw.charCodeAt(0) === 0xfeff) {
    raw = raw.slice(1);
  }
  const parsed = dotenv.parse(raw);
  for (const [key, value] of Object.entries(parsed)) {
    if (override || process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

/** Carga .env.staging + .env.supabase-keys.local (override). */
export function loadStagingWithKeys(): LoadedPostgresEnv {
  const loaded = loadPostgresEnv('staging');
  loadEnvFileIntoProcess(KEYS_LOCAL, true);
  return loaded;
}

export function supabaseAccessToken(): string {
  return process.env.SUPABASE_ACCESS_TOKEN?.trim() ?? '';
}

export function hasSupabaseAccessToken(): boolean {
  return supabaseAccessToken().length > 0;
}
