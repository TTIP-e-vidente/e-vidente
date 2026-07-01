import fs from 'fs';
import path from 'path';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';
import {
  canReachSupabaseEmailEdge,
  isSupabaseApiEdgeMode,
  isSupabaseEmailEdgeMode,
} from '../src/config/supabase-email-mode';
import { loadBackendEnv } from './lib/postgres-env';
import { isLocalBackendUrl, resolvePublicBackendUrl } from './lib/cloud-backend-url';
import { resolveSupabaseClientApiKey, resolveSupabaseFunctionsUrl } from './lib/supabase-functions-env';
import { buildStorageNamespace } from './lib/godot-backend-config';

loadBackendEnv();

const publicUrl = resolvePublicBackendUrl();
const useCloudApi = !isLocalBackendUrl(publicUrl);
const apiEdgeMode = isSupabaseApiEdgeMode();
const emailViaSupabase = isSupabaseEmailEdgeMode();
const supabaseFunctionsUrl = emailViaSupabase ? resolveSupabaseFunctionsUrl() : '';
const supabaseAnonKey = emailViaSupabase ? resolveSupabaseClientApiKey() : '';
const envFile = process.env.ENV_FILE?.trim() || '.env';
const emailEnabled = ['true', '1', 'yes'].includes(
  (process.env.EMAIL_ENABLED ?? '').trim().toLowerCase()
);

const localExpressUrl = `http://${(process.env.BACKEND_HOST ?? 'localhost').trim()}:${process.env.BACKEND_PORT ?? '3010'}`;

let apiMode: 'local' | 'cloud' | 'supabase_edge';
let baseUrl: string;

if (apiEdgeMode) {
  apiMode = 'supabase_edge';
  baseUrl = supabaseFunctionsUrl;
} else if (useCloudApi) {
  apiMode = 'cloud';
  baseUrl = publicUrl;
} else {
  apiMode = 'local';
  baseUrl = localExpressUrl;
}

const targetPath = path.resolve(__dirname, '../../juego/config/backend.local.json');

const payload = {
  base_url: baseUrl,
  env_file: envFile,
  db: isRemotePostgres() ? 'supabase' : 'local',
  email_enabled: emailEnabled,
  email_via_supabase: emailViaSupabase,
  supabase_functions_url: supabaseFunctionsUrl,
  supabase_anon_key: supabaseAnonKey,
  api_mode: apiMode,
  storage_namespace: buildStorageNamespace({
    db: isRemotePostgres() ? 'supabase' : 'local',
    apiMode,
    envFile,
    baseUrl,
  }),
  synced_at: new Date().toISOString(),
};

fs.mkdirSync(path.dirname(targetPath), { recursive: true });
fs.writeFileSync(targetPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');

const modeLabel = apiEdgeMode
  ? 'supabase_edge (sin Express)'
  : useCloudApi
    ? 'cloud (sin terminal local)'
    : 'local';
const verifyLabel = emailViaSupabase
  ? canReachSupabaseEmailEdge()
    ? ' · verify→supabase'
    : ' · verify→supabase (falta anon key)'
  : '';
console.log(
  `[sync] Godot → ${baseUrl} · ${payload.db} · ${modeLabel}${emailEnabled ? ' · brevo-edge' : ''}${verifyLabel} (${path.relative(process.cwd(), targetPath)})`
);
