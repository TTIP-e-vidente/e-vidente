import assert from 'assert/strict';
import { loadPostgresEnv } from './lib/postgres-env';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';

type JsonObject = Record<string, unknown>;

async function requestJson(
  url: string,
  options: RequestInit = {},
): Promise<{ status: number; body: JsonObject }> {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
  const text = await response.text();
  return {
    status: response.status,
    body: text ? (JSON.parse(text) as JsonObject) : {},
  };
}

async function main(): Promise<void> {
  loadPostgresEnv('staging');

  if (!canUseSupabaseEmailFunctions()) {
    console.error('[smoke:verify-edge] FAIL — falta SUPABASE_ANON_KEY o SUPABASE_PROJECT_REF');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = process.env.SUPABASE_ANON_KEY!.trim();

  const health = await requestJson(`${baseUrl}/verify-email-health`, {
    method: 'GET',
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
    },
  });

  assert.equal(health.status, 200, `health HTTP ${health.status}`);
  assert.equal(health.body.ok, true);
  console.log('[smoke:verify-edge] OK health', health.body);

  const invalid = await requestJson(`${baseUrl}/verify-email-request`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      Authorization: 'Bearer invalid-token',
    },
    body: JSON.stringify({}),
  });
  assert.equal(invalid.status, 401, 'token inválido debe dar 401');
  console.log('[smoke:verify-edge] OK auth guard (401 sin JWT válido)');
}

main().catch((error) => {
  console.error('[smoke:verify-edge] FAIL', error);
  process.exit(1);
});
