import assert from 'assert/strict';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';

type JsonObject = Record<string, unknown>;

const SCOPES = [
  'global_xp',
  'streak',
  'restriction:CELIAQUIA',
  'restriction:VEG',
  'restriction:VYG',
  'restriction:KETO',
] as const;

async function requestJson(
  url: string,
  options: RequestInit = {},
): Promise<{ status: number; body: JsonObject; headers: Headers }> {
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
    headers: response.headers,
  };
}

async function main(): Promise<void> {
  loadStagingWithKeys();

  if (!canUseSupabaseEmailFunctions()) {
    console.error('[smoke:leaderboard-edge] FAIL — falta SUPABASE_ANON_KEY o SUPABASE_PROJECT_REF');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const publicHeaders = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
  };

  const cronSecret = process.env.EMAIL_CRON_SECRET?.trim() ?? '';
  if (cronSecret.length >= 12) {
    const refresh = await requestJson(`${baseUrl}/internal-job`, {
      method: 'POST',
      headers: {
        ...publicHeaders,
        'X-Job-Secret': cronSecret,
      },
      body: JSON.stringify({ job: 'refresh-leaderboard' }),
    });
    assert.equal(refresh.status, 200, `refresh-leaderboard HTTP ${refresh.status}`);
    const results = refresh.body.results as JsonObject[] | undefined;
    assert.ok(Array.isArray(results), 'refresh results debe ser array');
    console.log('[smoke:leaderboard-edge] OK refresh-leaderboard');
  } else {
    console.warn('[smoke:leaderboard-edge] SKIP refresh (EMAIL_CRON_SECRET corto)');
  }

  const list = await requestJson(`${baseUrl}/leaderboard-list`, {
    method: 'GET',
    headers: publicHeaders,
  });
  assert.equal(list.status, 200, `leaderboard-list HTTP ${list.status}`);
  assert.ok(Array.isArray(list.body.entries));
  assert.equal(typeof list.body.total, 'number');
  console.log('[smoke:leaderboard-edge] OK leaderboard-list default');

  const streak = await requestJson(`${baseUrl}/leaderboard-list?scope=streak`, {
    method: 'GET',
    headers: publicHeaders,
  });
  assert.equal(streak.status, 200);
  assert.equal(streak.body.scope, 'streak');
  console.log('[smoke:leaderboard-edge] OK leaderboard-list streak');

  for (const scope of SCOPES.filter((s) => s.startsWith('restriction:'))) {
    const scoped = await requestJson(
      `${baseUrl}/leaderboard-list?scope=${encodeURIComponent(scope)}`,
      { method: 'GET', headers: publicHeaders },
    );
    assert.equal(scoped.status, 200, `${scope} HTTP ${scoped.status}`);
    assert.equal(scoped.body.scope, scope);
  }
  console.log('[smoke:leaderboard-edge] OK restriction scopes');

  const invalid = await requestJson(`${baseUrl}/leaderboard-list?scope=INVALID`, {
    method: 'GET',
    headers: publicHeaders,
  });
  assert.equal(invalid.status, 200);
  assert.equal(invalid.body.scope, 'global_xp');
  console.log('[smoke:leaderboard-edge] OK scope inválido → fallback global_xp');

  const meta = await requestJson(`${baseUrl}/leaderboard-meta`, {
    method: 'GET',
    headers: publicHeaders,
  });
  assert.equal(meta.status, 200);
  assert.ok(Array.isArray(meta.body.snapshots));
  console.log('[smoke:leaderboard-edge] OK leaderboard-meta');

  const meNoAuth = await requestJson(`${baseUrl}/leaderboard-me`, {
    method: 'GET',
    headers: {
      apikey: anonKey,
      'Content-Type': 'application/json',
    },
  });
  assert.equal(meNoAuth.status, 401);
  console.log('[smoke:leaderboard-edge] OK leaderboard-me sin JWT de usuario → 401');

  const suffix = Date.now();
  const register = await requestJson(`${baseUrl}/auth-register`, {
    method: 'POST',
    headers: publicHeaders,
    body: JSON.stringify({
      username: `edge_lb_${suffix}`,
      name: 'Edge LB Smoke',
      mail: `edge_lb_${suffix}@test.com`,
      password: 'Password123',
      birth_date: '2000-06-15',
      accept_email_notifications: false,
    }),
  });
  assert.equal(register.status, 201);
  const token = register.body.accessToken as string;
  const authHeaders = { ...publicHeaders, Authorization: `Bearer ${token}` };

  const me = await requestJson(`${baseUrl}/leaderboard-me`, {
    method: 'GET',
    headers: authHeaders,
  });
  assert.equal(me.status, 200);
  assert.ok(Array.isArray(me.body.positions));
  console.log('[smoke:leaderboard-edge] OK leaderboard-me con auth');

  const summary = await requestJson(
    `${baseUrl}/leaderboard-me-summary?scope=global_xp`,
    { method: 'GET', headers: authHeaders },
  );
  assert.equal(summary.status, 200);
  console.log('[smoke:leaderboard-edge] OK leaderboard-me-summary');
}

main().catch((error) => {
  console.error('[smoke:leaderboard-edge] FAIL', error);
  process.exit(1);
});
