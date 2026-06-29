import fs from 'fs';
import path from 'path';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';
import {
  canReachSupabaseEmailEdge,
  isSupabaseEmailEdgeMode,
} from '../src/config/supabase-email-mode';
import { loadBackendEnv } from './lib/postgres-env';
import { isLocalBackendUrl, resolvePublicBackendUrl } from './lib/cloud-backend-url';
import { resolveSupabaseFunctionsUrl } from './lib/supabase-functions-env';

loadBackendEnv();

const publicUrl = resolvePublicBackendUrl();
const useCloudApi = !isLocalBackendUrl(publicUrl);
const baseUrl = useCloudApi ? publicUrl : `http://${(process.env.BACKEND_HOST ?? 'localhost').trim()}:${process.env.BACKEND_PORT ?? '3010'}`;
const envFile = process.env.ENV_FILE?.trim() || '.env';
const emailEnabled = ['true', '1', 'yes'].includes(
  (process.env.EMAIL_ENABLED ?? '').trim().toLowerCase()
);
const emailViaSupabase = isSupabaseEmailEdgeMode();
const supabaseFunctionsUrl = emailViaSupabase ? resolveSupabaseFunctionsUrl() : '';
const supabaseAnonKey = emailViaSupabase ? (process.env.SUPABASE_ANON_KEY?.trim() ?? '') : '';

const targetPath = path.resolve(__dirname, '../../juego/config/backend.local.json');

const payload = {
  base_url: baseUrl,
  env_file: envFile,
  db: isRemotePostgres() ? 'supabase' : 'local',
  email_enabled: emailEnabled,
  email_via_supabase: emailViaSupabase,
  supabase_functions_url: supabaseFunctionsUrl,
  supabase_anon_key: supabaseAnonKey,
  api_mode: useCloudApi ? 'cloud' : 'local',
  synced_at: new Date().toISOString(),
};

fs.mkdirSync(path.dirname(targetPath), { recursive: true });
fs.writeFileSync(targetPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');

const modeLabel = useCloudApi ? 'cloud (sin terminal local)' : 'local';
const verifyLabel = emailViaSupabase
  ? canReachSupabaseEmailEdge()
    ? ' · verify→supabase'
    : ' · verify→supabase (falta anon key)'
  : '';
console.log(
  `[sync] Godot → ${baseUrl} · ${payload.db} · ${modeLabel}${emailEnabled ? ' · brevo-edge' : ''}${verifyLabel} (${path.relative(process.cwd(), targetPath)})`
);
