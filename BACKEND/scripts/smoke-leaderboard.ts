/**
 * Smoke test del leaderboard.
 * Verifica: endpoints públicos, meta, refresh job, cache headers, paginación.
 *
 * Uso:
 *   BACKEND_URL=http://localhost:3000 JOB_SECRET=xxx npx ts-node scripts/smoke-leaderboard.ts
 *   (JOB_SECRET puede omitirse — el test marcará el refresh como skipped)
 */
import dotenv from 'dotenv';
dotenv.config();

const BASE_URL    = process.env.BACKEND_URL ?? 'http://localhost:3000';
const JOB_SECRET  = process.env.INTERNAL_JOB_SECRET ?? '';
const AUTH_TOKEN  = process.env.SMOKE_AUTH_TOKEN ?? '';

type Color = 'green' | 'red' | 'yellow' | 'cyan';
const C: Record<Color, string> = { green: '\x1b[32m', red: '\x1b[31m', yellow: '\x1b[33m', cyan: '\x1b[36m' };
const R = '\x1b[0m';

function log(color: Color, icon: string, label: string, detail = ''): void {
  console.log(`${C[color]}${icon} ${label}${R}${detail ? ` — ${detail}` : ''}`);
}

interface CheckResult { ok: boolean; label: string; detail?: string }

async function check(label: string, fn: () => Promise<string | true>): Promise<CheckResult> {
  try {
    const result = await fn();
    if (result === true) {
      log('green', '✓', label);
      return { ok: true, label };
    }
    log('yellow', '⚠', label, result);
    return { ok: false, label, detail: result };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    log('red', '✗', label, msg);
    return { ok: false, label, detail: msg };
  }
}

async function get(path: string, headers: Record<string, string> = {}) {
  const res = await fetch(`${BASE_URL}${path}`, { headers });
  const body = await res.json() as Record<string, unknown>;
  return { status: res.status, headers: res.headers, body };
}

async function post(path: string, headers: Record<string, string> = {}) {
  const res = await fetch(`${BASE_URL}${path}`, { method: 'POST', headers });
  const body = await res.json() as Record<string, unknown>;
  return { status: res.status, body };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

const results: CheckResult[] = [];

async function run() {
  console.log(`\n${C.cyan}════ Leaderboard Smoke Test ════${R}`);
  console.log(`Target: ${BASE_URL}\n`);

  // 1. Refresh job (necesita JOB_SECRET)
  if (JOB_SECRET) {
    results.push(await check('POST /internal/jobs/refresh-leaderboard', async () => {
      const { status, body } = await post('/internal/jobs/refresh-leaderboard', {
        'x-job-secret': JOB_SECRET
      });
      if (status !== 200) return `HTTP ${status}: ${JSON.stringify(body)}`;
      const r = body.results as Array<{ scope: string; rowsInserted: number; durationMs: number; error?: string }>;
      if (!Array.isArray(r)) return 'results no es array';
      const errors = r.filter(x => x.error);
      if (errors.length > 0) return `errores en scopes: ${errors.map(x => `${x.scope}=${x.error}`).join(', ')}`;
      const summary = r.map(x => `${x.scope}:${x.rowsInserted}rows/${x.durationMs}ms`).join(', ');
      return `OK — ${summary}`;
    }));
  } else {
    log('yellow', '⚠', 'Refresh job', 'SKIPPED (JOB_SECRET no configurado)');
  }

  // 2. GET /leaderboard (scope default)
  results.push(await check('GET /leaderboard (global_xp, default)', async () => {
    const { status, headers, body } = await get('/leaderboard');
    if (status !== 200) return `HTTP ${status}`;
    if (!Array.isArray(body.entries)) return 'entries no es array';
    if (typeof body.total !== 'number') return 'total no es number';
    if (!body.pagination) return 'pagination ausente';
    const cc = headers.get('cache-control') ?? '';
    if (!cc.includes('max-age')) return `Cache-Control inválido: ${cc}`;
    return true;
  }));

  // 3. GET /leaderboard?scope=streak
  results.push(await check('GET /leaderboard?scope=streak', async () => {
    const { status, body } = await get('/leaderboard?scope=streak');
    if (status !== 200) return `HTTP ${status}`;
    if (body.scope !== 'streak') return `scope incorrecto: ${String(body.scope)}`;
    return true;
  }));

  // 4. Scope inválido → 400
  results.push(await check('GET /leaderboard?scope=INVALID → 400', async () => {
    const { status } = await get('/leaderboard?scope=INVALID');
    if (status !== 400) return `esperaba 400, got ${status}`;
    return true;
  }));

  // 5. Paginación
  results.push(await check('GET /leaderboard?limit=5&offset=0 — paginación', async () => {
    const { status, body } = await get('/leaderboard?limit=5&offset=0');
    if (status !== 200) return `HTTP ${status}`;
    const entries = body.entries as unknown[];
    if (!Array.isArray(entries)) return 'entries no es array';
    if (entries.length > 5) return `devolvió ${entries.length} entries, máximo 5`;
    if (typeof body.pagination !== 'object' || body.pagination === null) return 'pagination ausente';
    return true;
  }));

  // 6. ETag / 304 Not Modified
  results.push(await check('GET /leaderboard — ETag y 304 Not Modified', async () => {
    const first  = await get('/leaderboard');
    const etag   = first.headers.get('etag');
    if (!etag) {
      // Puede no tener ETag si el snapshot aún no existe (fallback en vivo)
      return first.body.is_live_fallback ? 'SKIPPED (live fallback, sin ETag)' : 'ETag ausente en snapshot';
    }
    const second = await fetch(`${BASE_URL}/leaderboard`, {
      headers: { 'if-none-match': etag }
    });
    if (second.status !== 304) return `esperaba 304, got ${second.status}`;
    return true;
  }));

  // 7. GET /leaderboard/meta
  results.push(await check('GET /leaderboard/meta', async () => {
    const { status, body } = await get('/leaderboard/meta');
    if (status !== 200) return `HTTP ${status}`;
    if (!Array.isArray(body.snapshots)) return 'snapshots no es array';
    if (typeof body.all_ok !== 'boolean') return 'all_ok ausente';
    const ss = body.snapshots as Array<{ scope: string; status: string; row_count: number }>;
    const summary = ss.map(s => `${s.scope}:${s.status}(${s.row_count} rows)`).join(', ');
    return `all_ok=${String(body.all_ok)} — ${summary}`;
  }));

  // 8. GET /leaderboard/me (sin auth → 401)
  results.push(await check('GET /leaderboard/me sin auth → 401', async () => {
    const { status } = await get('/leaderboard/me');
    if (status !== 401) return `esperaba 401, got ${status}`;
    return true;
  }));

  // 9. GET /leaderboard/me con auth
  if (AUTH_TOKEN) {
    results.push(await check('GET /leaderboard/me con Bearer', async () => {
      const { status, body } = await get('/leaderboard/me', {
        Authorization: `Bearer ${AUTH_TOKEN}`
      });
      if (status !== 200) return `HTTP ${status}: ${JSON.stringify(body)}`;
      if (!Array.isArray(body.positions)) return 'positions no es array';
      const pos = body.positions as Array<{ scope: string; rank: number | null }>;
      const summary = pos.map(p => `${p.scope}:rank=${String(p.rank)}`).join(', ');
      return `OK — ${summary}`;
    }));

    // 10. include_self con Bearer
    results.push(await check('GET /leaderboard?include_self=true con Bearer', async () => {
      const { status, body } = await get('/leaderboard?include_self=true', {
        Authorization: `Bearer ${AUTH_TOKEN}`
      });
      if (status !== 200) return `HTTP ${status}`;
      // own_position puede ser null si el usuario aún no tiene datos
      return `OK — own_position=${body.own_position === null ? 'null' : JSON.stringify(body.own_position)}`;
    }));
  } else {
    log('yellow', '⚠', '/leaderboard/me y include_self', 'SKIPPED (SMOKE_AUTH_TOKEN no configurado)');
  }

  // ─── Resumen ─────────────────────────────────────────────────────────────────
  console.log(`\n${C.cyan}════ Resumen ════${R}`);
  const passed  = results.filter(r => r.ok).length;
  const failed  = results.filter(r => !r.ok).length;

  if (failed === 0) {
    log('green', '✓', `Todos los tests pasaron (${passed}/${results.length})`);
  } else {
    log('red', '✗', `${failed} tests fallaron de ${results.length}`);
    for (const r of results.filter(r => !r.ok)) {
      log('red', '  ✗', r.label, r.detail ?? '');
    }
    process.exit(1);
  }
}

run().catch((e) => {
  console.error('\x1b[31mError inesperado:\x1b[0m', e);
  process.exit(1);
});
