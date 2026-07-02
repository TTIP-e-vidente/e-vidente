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

const targetPath = path.resolve(__dirname, '../../juego/config/backend.local.json');

// Config previa: si el env actual no tiene los datos de Supabase (p. ej.
// corriendo con .env local), se preservan del archivo anterior para que el
// modo auto pueda caer a Supabase Edge cuando el Express local no esté.
function readPreviousConfig(): Record<string, unknown> {
  try {
    const raw = fs.readFileSync(targetPath, 'utf8');
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    return typeof parsed === 'object' && parsed !== null ? parsed : {};
  } catch {
    return {};
  }
}
const previous = readPreviousConfig();

const effectiveSupabaseFunctionsUrl =
  supabaseFunctionsUrl || String(previous.supabase_functions_url ?? '').trim();
const effectiveSupabaseAnonKey =
  supabaseAnonKey || String(previous.supabase_anon_key ?? '').trim();

// Modo auto: Godot sondea el Express local al arrancar; si responde lo usa,
// si no cae a Supabase Edge. GODOT_API_MODE permite pinear un modo fijo
// (local | cloud | supabase_edge) para debug.
const pinnedMode = (process.env.GODOT_API_MODE ?? '').trim();
let apiMode: 'auto' | 'local' | 'cloud' | 'supabase_edge';
let baseUrl: string;

if (pinnedMode === 'local' || pinnedMode === 'cloud' || pinnedMode === 'supabase_edge') {
  apiMode = pinnedMode;
  baseUrl = pinnedMode === 'supabase_edge'
    ? effectiveSupabaseFunctionsUrl
    : pinnedMode === 'cloud'
      ? publicUrl
      : localExpressUrl;
} else if (effectiveSupabaseFunctionsUrl) {
  apiMode = 'auto';
  baseUrl = effectiveSupabaseFunctionsUrl;
} else if (apiEdgeMode) {
  apiMode = 'supabase_edge';
  baseUrl = supabaseFunctionsUrl;
} else if (useCloudApi) {
  apiMode = 'cloud';
  baseUrl = publicUrl;
} else {
  apiMode = 'local';
  baseUrl = localExpressUrl;
}

const payload = {
  base_url: baseUrl,
  local_base_url: localExpressUrl,
  env_file: envFile,
  db: isRemotePostgres() ? 'supabase' : 'local',
  email_enabled: emailEnabled,
  email_via_supabase: emailViaSupabase || apiMode === 'auto',
  supabase_functions_url: effectiveSupabaseFunctionsUrl,
  supabase_anon_key: effectiveSupabaseAnonKey,
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

const modeLabel = apiMode === 'auto'
  ? 'auto (Express local si responde; si no, Supabase Edge)'
  : apiEdgeMode
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
