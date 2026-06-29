import assert from 'assert/strict';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
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

async function waitScopeRefresh(
  baseUrl: string,
  headers: Record<string, string>,
  scope: string,
  sinceMs: number,
  maxWaitMs = 10000,
): Promise<void> {
  const deadline = Date.now() + maxWaitMs;
  while (Date.now() < deadline) {
    const meta = await requestJson(`${baseUrl}/leaderboard-meta`, { method: 'GET', headers });
    assert.equal(meta.status, 200, `leaderboard-meta HTTP ${meta.status}`);
    const snapshots = meta.body.snapshots as Array<Record<string, unknown>> | undefined;
    const snap = snapshots?.find((row) => row.scope === scope);
    const refreshedAt = snap?.last_refreshed_at;
    if (refreshedAt) {
      const refreshedMs = new Date(String(refreshedAt)).getTime();
      if (!Number.isNaN(refreshedMs) && refreshedMs >= sinceMs - 2000) {
        return;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  assert.fail(`scope ${scope} no refrescó tras player-progress-save`);
}

async function main(): Promise<void> {
  loadStagingWithKeys();

  if (!canUseSupabaseEmailFunctions()) {
    console.error('[smoke:progress-edge] FAIL — falta SUPABASE_ANON_KEY o SUPABASE_PROJECT_REF');
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
  const username = `edge_prog_${suffix}`;
  const mail = `edge_prog_${suffix}@test.com`;

  const register = await requestJson(`${baseUrl}/auth-register`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      username,
      name: 'Edge Progress Smoke',
      mail,
      password: 'Password123',
      birth_date: '2000-06-15',
      accept_email_notifications: false,
    }),
  });
  assert.equal(register.status, 201, `register HTTP ${register.status}`);
  const token = register.body.accessToken as string;
  const authHeaders = { ...headers, Authorization: `Bearer ${token}` };

  const emptyProgress = await requestJson(`${baseUrl}/player-progress-get`, {
    method: 'GET',
    headers: authHeaders,
  });
  assert.equal(emptyProgress.status, 200, `progress-get HTTP ${emptyProgress.status}`);
  assert.ok(Array.isArray(emptyProgress.body.progress));
  console.log('[smoke:progress-edge] OK progress-get');

  const saveStarted = Date.now();
  const save = await requestJson(`${baseUrl}/player-progress-save`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      clientRunId: `smoke_run_${suffix}`,
      restriction: 'CELIAQUIA',
      expToAdd: 15,
      nodeId: `smoke_node_${suffix}`,
      gameType: 'quiz',
      accuracy: 90,
      completed: true,
      score: 100,
    }),
  });
  assert.equal(save.status, 201, `progress-save HTTP ${save.status}`);
  const progress = save.body.progress as JsonObject;
  assert.ok(Number(progress?.total_exp) >= 15);
  console.log('[smoke:progress-edge] OK progress-save');

  const afterSave = await requestJson(`${baseUrl}/player-progress-get`, {
    method: 'GET',
    headers: authHeaders,
  });
  assert.equal(afterSave.status, 200);
  const progressList = afterSave.body.progress as JsonObject[];
  const celiaquia = progressList.find((p) => p.restriction_type === 'CELIAQUIA');
  assert.ok(celiaquia && Number(celiaquia.total_exp) >= 15);
  console.log('[smoke:progress-edge] OK progress persisted');

  await waitScopeRefresh(baseUrl, headers, 'global_xp', saveStarted);
  await waitScopeRefresh(baseUrl, headers, 'restriction:CELIAQUIA', saveStarted);
  console.log('[smoke:progress-edge] OK leaderboard refresh post-save');

  const reset = await requestJson(`${baseUrl}/player-progress-reset`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({ restriction: 'CELIAQUIA' }),
  });
  assert.equal(reset.status, 200, `progress-reset HTTP ${reset.status}`);
  console.log('[smoke:progress-edge] OK progress-reset');
}

main().catch((error) => {
  console.error('[smoke:progress-edge] FAIL', error);
  process.exit(1);
});
