/**
 * Smoke: progreso → refresh ranking → mejora de puesto detectable.
 * Valida la lógica de celebración (antes/después) vía leaderboard-me-summary.
 */
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

function rankFromSummary(body: JsonObject): number {
  const current = body.current as JsonObject | undefined;
  return Number.parseInt(String(current?.rank ?? '0'), 10);
}

function wouldCelebrate(before: number, after: number): boolean {
  if (after <= 0) return false;
  if (before <= 0) return true;
  return after < before;
}

async function waitScopeRefresh(
  baseUrl: string,
  headers: Record<string, string>,
  scope: string,
  sinceMs: number,
): Promise<void> {
  const deadline = Date.now() + 12000;
  while (Date.now() < deadline) {
    const meta = await requestJson(`${baseUrl}/leaderboard-meta`, { method: 'GET', headers });
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
  assert.fail(`scope ${scope} no refrescó tras progress-save`);
}

async function main(): Promise<void> {
  loadStagingWithKeys();

  if (!canUseSupabaseEmailFunctions()) {
    console.error('[smoke:ranking-celebration] FAIL — falta SUPABASE_ANON_KEY');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
  };
  const scope = 'global_xp';

  const suffix = Date.now();
  const username = `edge_rank_${suffix}`;
  const mail = `edge_rank_${suffix}@test.com`;

  const register = await requestJson(`${baseUrl}/auth-register`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      username,
      name: 'Rank Celebration Smoke',
      mail,
      password: 'Password123',
      birth_date: '2000-06-15',
      accept_email_notifications: false,
    }),
  });
  assert.equal(register.status, 201);
  const token = register.body.accessToken as string;
  const authHeaders = { ...headers, Authorization: `Bearer ${token}` };

  const summaryBefore = await requestJson(
    `${baseUrl}/leaderboard-me-summary?scope=${encodeURIComponent(scope)}`,
    { method: 'GET', headers: authHeaders },
  );
  assert.equal(summaryBefore.status, 200);
  const rankBefore = summaryBefore.body.available === false ? 0 : rankFromSummary(summaryBefore.body);
  console.log('[smoke:ranking-celebration] rank antes:', rankBefore || '(sin ranking)');

  const saveStarted = Date.now();
  const save = await requestJson(`${baseUrl}/player-progress-save`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      clientRunId: `rank_smoke_${suffix}`,
      restriction: 'CELIAQUIA',
      expToAdd: 120,
      nodeId: `rank_node_${suffix}`,
      gameType: 'quiz',
      accuracy: 95,
      completed: true,
      score: 100,
    }),
  });
  assert.equal(save.status, 201, `progress-save HTTP ${save.status}`);

  await waitScopeRefresh(baseUrl, headers, scope, saveStarted);

  const summaryAfter = await requestJson(
    `${baseUrl}/leaderboard-me-summary?scope=${encodeURIComponent(scope)}`,
    { method: 'GET', headers: authHeaders },
  );
  assert.equal(summaryAfter.status, 200);
  assert.equal(summaryAfter.body.available, true, 'summary debe estar available tras partida');
  const rankAfter = rankFromSummary(summaryAfter.body);
  assert.ok(rankAfter > 0, 'rank después debe ser > 0');

  const celebrate = wouldCelebrate(rankBefore, rankAfter);
  console.log('[smoke:ranking-celebration] rank después:', rankAfter, 'celebraría:', celebrate);

  if (rankBefore > 0) {
    assert.ok(rankAfter <= rankBefore, 'con EXP nueva el puesto no debería empeorar');
  } else {
    assert.ok(celebrate, 'primera aparición en ranking debería celebrar');
  }

  console.log('[smoke:ranking-celebration] OK');
}

main().catch((error) => {
  console.error('[smoke:ranking-celebration] FAIL', error);
  process.exit(1);
});
