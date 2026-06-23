import * as leaderboardRepository from './leaderboard.repository';
import { cacheGet, cacheInvalidate, cacheSet } from './leaderboard.cache';
import {
  GetLeaderboardFilters,
  LEADERBOARD_SCOPE_LABELS,
  LEADERBOARD_SCOPES,
  LeaderboardEntry,
  LeaderboardResult,
  LeaderboardScope,
  RankingSummary,
  RefreshLeaderboardResult,
  UserLeaderboardPosition,
  isRestrictionLeaderboardScope,
  restrictionFromLeaderboardScope
} from './leaderboard.types';
import { VALID_RESTRICTIONS } from '../../config/restrictions';

const DEFAULT_LIMIT               = 50;
const MAX_LIMIT                   = 200;
const CACHE_TTL_MS                = 60_000;    // 60s frescos
const BACKGROUND_REFRESH_DEBOUNCE = 5_000;     // debounce para triggers desde progreso

// ─── Guard de concurrencia ────────────────────────────────────────────────────

const refreshingScopes = new Set<LeaderboardScope>();

// ─── Parsing ──────────────────────────────────────────────────────────────────

export function parseScope(value: unknown): LeaderboardScope | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  if ((LEADERBOARD_SCOPES as string[]).includes(trimmed)) {
    return trimmed as LeaderboardScope;
  }

  const lower = trimmed.toLowerCase();
  if (lower === 'global_xp' || lower === 'streak') {
    return lower as LeaderboardScope;
  }

  if (lower.startsWith('restriction:')) {
    const code = trimmed.slice('restriction:'.length).toUpperCase();
    if ((VALID_RESTRICTIONS as readonly string[]).includes(code)) {
      const scope = `restriction:${code}` as LeaderboardScope;
      if ((LEADERBOARD_SCOPES as string[]).includes(scope)) return scope;
    }
  }

  return undefined;
}

function parseLimit(value: unknown): number {
  if (typeof value === 'string' || typeof value === 'number') {
    const n = parseInt(String(value), 10);
    if (!isNaN(n) && n > 0) return Math.min(n, MAX_LIMIT);
  }
  return DEFAULT_LIMIT;
}

function parseOffset(value: unknown): number {
  if (typeof value === 'string' || typeof value === 'number') {
    const n = parseInt(String(value), 10);
    if (!isNaN(n) && n >= 0) return n;
  }
  return 0;
}

// ─── Lectura con cache + stale-while-revalidate ───────────────────────────────

export async function getLeaderboard(filters: GetLeaderboardFilters = {}): Promise<LeaderboardResult> {
  const scope  = parseScope(filters.scope) ?? 'global_xp';
  const limit  = parseLimit(filters.limit);
  const offset = parseOffset(filters.offset);

  const cacheKey = `${scope}:${limit}:${offset}`;
  const cached   = cacheGet<LeaderboardResult>(cacheKey);

  if (cached) {
    if (cached.stale) {
      // Stale-while-revalidate: refresca en background sin bloquear la respuesta
      scheduleBackgroundRefresh(scope);
    }
    return injectOwnPosition(cached.data, filters);
  }

  const result = await computeLeaderboard(scope, limit, offset);
  cacheSet(cacheKey, result, CACHE_TTL_MS);
  return injectOwnPosition(result, filters);
}

async function computeLeaderboard(
  scope: LeaderboardScope,
  limit: number,
  offset: number
): Promise<LeaderboardResult> {
  // Meta y entries en paralelo — meta.row_count reemplaza COUNT(*) extra
  const [entries, meta] = await Promise.all([
    leaderboardRepository.getTopEntries(scope, limit, offset),
    leaderboardRepository.getMeta(scope)
  ]);

  const total = meta?.rowCount ?? 0;

  if (entries.length > 0) {
    return {
      scope,
      scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
      entries,
      ownPosition: null,
      computedAt: meta?.lastRefreshedAt ?? null,
      total,
      isStale: false,
      isLiveFallback: false,
      pagination: { limit, offset, hasMore: offset + entries.length < total }
    };
  }

  // Snapshot vacío → fallback en vivo
  const liveEntries = await getLiveEntriesForScope(scope, limit, offset);
  return {
    scope,
    scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
    entries: liveEntries,
    ownPosition: null,
    computedAt: null,
    total: liveEntries.length,
    isStale: false,
    isLiveFallback: true,
    pagination: { limit, offset, hasMore: false }
  };
}

async function getLiveEntriesForScope(
  scope: LeaderboardScope,
  limit: number,
  offset: number
): Promise<LeaderboardEntry[]> {
  if (scope === 'global_xp') {
    return leaderboardRepository.getLiveGlobalXpEntries(limit, offset);
  }
  if (scope === 'streak') {
    return leaderboardRepository.getLiveStreakEntries(limit, offset);
  }
  const restriction = restrictionFromLeaderboardScope(scope);
  if (restriction) {
    return leaderboardRepository.getLiveRestrictionEntries(restriction, limit, offset);
  }
  return [];
}

/**
 * Inyecta la posición propia en la respuesta (no se cachea: es dato personal).
 * Ahora incluye username/displayName/avatarKey desde el snapshot o live fallback.
 */
async function injectOwnPosition(
  result: LeaderboardResult,
  filters: GetLeaderboardFilters
): Promise<LeaderboardResult> {
  if (!filters.includeSelf || !filters.userId) return result;

  // Optimización: si ya aparece en la página actual, no hace round-trip
  const inPage = result.entries.find((e) => e.userId === filters.userId);
  if (inPage) return { ...result, ownPosition: inPage };

  // Desde snapshot (tiene datos completos: username, displayName, avatarKey)
  const snapshotRow = await leaderboardRepository.getUserRankInSnapshot(result.scope, filters.userId);
  if (snapshotRow) {
    const { computedAt: _, ...entry } = snapshotRow;
    return { ...result, ownPosition: entry };
  }

  // Fallback en vivo (solo rank + score — el cliente ya tiene el resto)
  const liveRow = await leaderboardRepository.getLiveUserRank(result.scope, filters.userId);
  if (!liveRow) return result;
  return {
    ...result,
    ownPosition: {
      rank: liveRow.rank,
      userId: filters.userId,
      username: '',
      displayName: null,
      avatarKey: null,
      score: liveRow.score
    }
  };
}

// ─── Posición propia (endpoint /me) ───────────────────────────────────────────

export async function getUserLeaderboardPositions(userId: string): Promise<UserLeaderboardPosition[]> {
  return Promise.all(
    LEADERBOARD_SCOPES.map(async (scope) => {
      const row = await leaderboardRepository.getUserRankInSnapshot(scope, userId);
      if (row) {
        return {
          scope,
          scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
          rank: row.rank,
          score: row.score,
          computedAt: row.computedAt
        };
      }
      // Snapshot no tiene al usuario → fallback en vivo (coste: window function sobre toda la tabla)
      const live = await leaderboardRepository.getLiveUserRank(scope, userId);
      return {
        scope,
        scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
        rank: live?.rank ?? null,
        score: live?.score ?? null,
        computedAt: null
      };
    })
  );
}

// ─── Metadata pública ─────────────────────────────────────────────────────────

export async function getLeaderboardMeta() {
  return leaderboardRepository.getAllMeta();
}

// ─── Resumen competitivo (/me/summary) ────────────────────────────────────────

/**
 * Construye el resumen competitivo del jugador autenticado.
 *
 * Lógica de progreso:
 *   - Si el jugador está primero: isFirstPlace=true, progressToNextRank=100, next=null.
 *   - Si tiene rival: progressToNextRank = (current.score / next.score) * 100, capped a 99
 *     (nunca se muestra 100% si no superó al rival; superar implica rank menor).
 *   - Si el rival tiene score 0 y el jugador también: 0%.
 *
 * Retorna null si el jugador no aparece en ningún registro (sin progreso registrado).
 */
export async function getUserRankingSummary(
  userId: string,
  scope: LeaderboardScope = 'global_xp',
  nearbyRadius: number = 2
): Promise<RankingSummary | null> {
  const context = await leaderboardRepository.getUserRankingContext(userId, scope);
  if (!context) return null;

  const { current, next, isFromSnapshot } = context;
  const nearbyEntries = await leaderboardRepository.getNearbyEntries(userId, scope, nearbyRadius);

  if (!next) {
    return {
      scope,
      scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
      current,
      next: null,
      expToNextRank: 0,
      progressToNextRank: 100,
      isFirstPlace: true,
      isFromSnapshot,
      nearbyEntries
    };
  }

  const expToNextRank = Math.max(next.score - current.score + 1, 0);

  let progressToNextRank = 0;
  if (next.score > 0) {
    progressToNextRank = Math.min(
      Math.floor((current.score / next.score) * 100),
      99
    );
  }

  return {
    scope,
    scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
    current,
    next,
    expToNextRank,
    progressToNextRank,
    isFirstPlace: false,
    isFromSnapshot,
    nearbyEntries
  };
}

// ─── Refresh ──────────────────────────────────────────────────────────────────

const pendingRefreshTimers = new Map<LeaderboardScope, ReturnType<typeof setTimeout>>();

function scheduleBackgroundRefresh(scope: LeaderboardScope): void {
  if (refreshingScopes.has(scope)) return;

  const existing = pendingRefreshTimers.get(scope);
  if (existing) clearTimeout(existing);

  const timer = setTimeout(() => {
    pendingRefreshTimers.delete(scope);
    void refreshLeaderboard(scope).catch((err) => {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`[leaderboard] background refresh ${scope} failed: ${msg}`);
    });
  }, BACKGROUND_REFRESH_DEBOUNCE);

  pendingRefreshTimers.set(scope, timer);
}

export async function refreshLeaderboard(scope: LeaderboardScope): Promise<RefreshLeaderboardResult> {
  if (refreshingScopes.has(scope)) {
    console.log(`[leaderboard] ${scope} refresh already running, skipping`);
    return { scope, rowsInserted: 0, durationMs: 0 };
  }

  refreshingScopes.add(scope);
  const startedAt = new Date();

  try {
    let rowsInserted = 0;
    if (scope === 'global_xp') {
      rowsInserted = await leaderboardRepository.refreshGlobalXpSnapshot(startedAt);
    } else if (scope === 'streak') {
      rowsInserted = await leaderboardRepository.refreshStreakSnapshot(startedAt);
    } else {
      const restriction = restrictionFromLeaderboardScope(scope);
      if (restriction) {
        rowsInserted = await leaderboardRepository.refreshRestrictionSnapshot(restriction, startedAt);
      }
    }

    cacheInvalidate(scope);
    return { scope, rowsInserted, durationMs: Date.now() - startedAt.getTime() };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return { scope, rowsInserted: 0, durationMs: Date.now() - startedAt.getTime(), error: msg };
  } finally {
    refreshingScopes.delete(scope);
  }
}

export async function refreshAllLeaderboards(): Promise<RefreshLeaderboardResult[]> {
  const results: RefreshLeaderboardResult[] = [];
  for (const scope of LEADERBOARD_SCOPES) {
    const result = await refreshLeaderboard(scope);
    results.push(result);
    const status = result.error ? `ERROR: ${result.error}` : `${result.rowsInserted} rows`;
    console.log(`[leaderboard] ${scope}: ${status} in ${result.durationMs}ms`);
  }
  return results;
}

/**
 * Warm-up: llama al arrancar el servidor si los snapshots están vacíos o muy stale.
 * Fire-and-forget — no bloquea el startup.
 */
export function warmUpLeaderboard(): void {
  for (const scope of LEADERBOARD_SCOPES) {
    void leaderboardRepository.getMeta(scope).then((meta) => {
      const noSnapshot = !meta || meta.rowCount === 0;
      const staleMs    = meta?.lastRefreshedAt
        ? Date.now() - meta.lastRefreshedAt.getTime()
        : Infinity;
      const tooStale   = staleMs > 10 * 60_000; // más de 10 minutos

      if (noSnapshot || tooStale) {
        console.log(`[leaderboard] warm-up: refreshing ${scope} (noSnapshot=${noSnapshot}, staleMs=${staleMs})`);
        scheduleBackgroundRefresh(scope);
      } else {
        console.log(`[leaderboard] warm-up: ${scope} is fresh (${Math.round(staleMs / 1000)}s old, ${meta.rowCount} rows)`);
      }
    }).catch((err) => {
      console.error(`[leaderboard] warm-up check failed for ${scope}:`, err);
    });
  }
}

/**
 * Trigger no bloqueante para disparar refresh cuando cambia el progreso de un jugador.
 * Debounce de 5s — múltiples llamadas en ráfaga producen un único refresh.
 */
export function triggerLeaderboardRefresh(): void {
  for (const scope of LEADERBOARD_SCOPES) {
    scheduleBackgroundRefresh(scope);
  }
}
