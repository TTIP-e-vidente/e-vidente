import assert from 'assert/strict';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';

type JsonObject = Record<string, unknown>;

const TINY_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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
  loadStagingWithKeys();

  if (!canUseSupabaseEmailFunctions()) {
    console.error('[smoke:avatar-edge] FAIL — falta SUPABASE_ANON_KEY o SUPABASE_PROJECT_REF');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
  };

  const suffix = Date.now();
  const username = `edge_avatar_${suffix}`;
  const mail = `edge_avatar_${suffix}@test.com`;

  const register = await requestJson(`${baseUrl}/auth-register`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      username,
      name: 'Edge Avatar Smoke',
      mail,
      password: 'Password123',
      birth_date: '2000-06-15',
      accept_email_notifications: false,
    }),
  });
  assert.equal(register.status, 201, `register HTTP ${register.status}`);
  const token = register.body.accessToken as string;
  const user = register.body.user as JsonObject;
  const userId = user.id as string;
  const authHeaders = { ...headers, Authorization: `Bearer ${token}` };

  const upload = await requestJson(`${baseUrl}/avatar-upload`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      data: TINY_PNG_BASE64,
      mimeType: 'image/png',
    }),
  });
  assert.equal(upload.status, 200, `avatar-upload HTTP ${upload.status}`);
  assert.ok(upload.body.updatedAt);
  console.log('[smoke:avatar-edge] OK avatar-upload');

  const getOwn = await requestJson(`${baseUrl}/avatar-get`, {
    method: 'GET',
    headers: authHeaders,
  });
  assert.equal(getOwn.status, 200, `avatar-get HTTP ${getOwn.status}`);
  assert.equal(getOwn.body.data, TINY_PNG_BASE64);
  assert.equal(getOwn.body.mimeType, 'image/png');
  console.log('[smoke:avatar-edge] OK avatar-get');

  const getPublic = await requestJson(
    `${baseUrl}/avatar-public?userId=${encodeURIComponent(userId)}`,
    {
      method: 'GET',
      headers,
    },
  );
  assert.equal(getPublic.status, 200, `avatar-public HTTP ${getPublic.status}`);
  assert.equal(getPublic.body.data, TINY_PNG_BASE64);
  console.log('[smoke:avatar-edge] OK avatar-public');

  const del = await requestJson(`${baseUrl}/avatar-delete`, {
    method: 'DELETE',
    headers: authHeaders,
  });
  assert.equal(del.status, 200, `avatar-delete HTTP ${del.status}`);
  console.log('[smoke:avatar-edge] OK avatar-delete');

  const afterDelete = await requestJson(`${baseUrl}/avatar-get`, {
    method: 'GET',
    headers: authHeaders,
  });
  assert.equal(afterDelete.status, 200);
  assert.equal(afterDelete.body.data, null);
  console.log('[smoke:avatar-edge] OK avatar removed');
}

main().catch((error) => {
  console.error('[smoke:avatar-edge] FAIL', error);
  process.exit(1);
});
