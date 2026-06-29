import * as leaderboardRepository from '../leaderboard/repository.ts';
import {
  serializeLeaderboardResult,
  serializeMeta,
  serializeRankingSummary,
  serializeUserPosition,
} from '../leaderboard/mapper.ts';
import {
  GetLeaderboardFilters,
  LEADERBOARD_SCOPE_LABELS,
  LEADERBOARD_SCOPES,
  LeaderboardEntry,
  LeaderboardResult,
  LeaderboardScope,
  RankingSummary,
  UserLeaderboardPosition,
  isRestrictionLeaderboardScope,
  restrictionFromLeaderboardScope,
} from '../leaderboard/types.ts';
import { VALID_RESTRICTIONS } from '../restrictions.ts';

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

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

async function computeLeaderboard(
  scope: LeaderboardScope,
  limit: number,
  offset: number,
): Promise<LeaderboardResult> {
  const [entries, meta] = await Promise.all([
    leaderboardRepository.getTopEntries(scope, limit, offset),
    leaderboardRepository.getMeta(scope),
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
      pagination: { limit, offset, hasMore: offset + entries.length < total },
    };
  }
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
    pagination: { limit, offset, hasMore: false },
  };
}

async function getLiveEntriesForScope(
  scope: LeaderboardScope,
  limit: number,
  offset: number,
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

async function injectOwnPosition(
  result: LeaderboardResult,
  filters: GetLeaderboardFilters,
): Promise<LeaderboardResult> {
  if (!filters.includeSelf || !filters.userId) return result;
  const inPage = result.entries.find((e) => e.userId === filters.userId);
  if (inPage) return { ...result, ownPosition: inPage };
  const snapshotRow = await leaderboardRepository.getUserRankInSnapshot(
    result.scope,
    filters.userId,
  );
  if (snapshotRow) {
    const { computedAt: _, ...entry } = snapshotRow;
    return { ...result, ownPosition: entry };
  }
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
      score: liveRow.score,
    },
  };
}

export async function getLeaderboard(filters: GetLeaderboardFilters = {}) {
  const scope = parseScope(filters.scope) ?? 'global_xp';
  const limit = parseLimit(filters.limit);
  const offset = parseOffset(filters.offset);
  const result = await computeLeaderboard(scope, limit, offset);
  const withSelf = await injectOwnPosition(result, filters);
  return serializeLeaderboardResult(withSelf);
}

export async function getUserLeaderboardPositions(userId: string) {
  const positions: UserLeaderboardPosition[] = await Promise.all(
    LEADERBOARD_SCOPES.map(async (scope) => {
      const row = await leaderboardRepository.getUserRankInSnapshot(scope, userId);
      if (row) {
        return {
          scope,
          scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
          rank: row.rank,
          score: row.score,
          computedAt: row.computedAt,
        };
      }
      const live = await leaderboardRepository.getLiveUserRank(scope, userId);
      return {
        scope,
        scopeLabel: LEADERBOARD_SCOPE_LABELS[scope],
        rank: live?.rank ?? null,
        score: live?.score ?? null,
        computedAt: null,
      };
    }),
  );
  return { positions: positions.map(serializeUserPosition) };
}

export async function getLeaderboardMetaPublic() {
  const metas = await leaderboardRepository.getAllMeta();
  return {
    snapshots: metas.map(serializeMeta),
    all_ok: metas.every((m) => !m.errorMessage && m.lastRefreshedAt !== null),
  };
}

export async function getUserRankingSummaryPublic(
  userId: string,
  scopeInput?: unknown,
) {
  const scope = scopeInput !== undefined ? parseScope(scopeInput) : 'global_xp';
  if (scopeInput !== undefined && !scope) {
    throw new Error(`scope inválido. Valores aceptados: ${LEADERBOARD_SCOPES.join(', ')}`);
  }
  const context = await leaderboardRepository.getUserRankingContext(userId, scope ?? 'global_xp');
  if (!context) return { available: false };
  const nearbyEntries = await leaderboardRepository.getNearbyEntries(
    userId,
    scope ?? 'global_xp',
    2,
  );
  let summary: RankingSummary;
  const { current, next, isFromSnapshot } = context;
  if (!next) {
    summary = {
      scope: scope ?? 'global_xp',
      scopeLabel: LEADERBOARD_SCOPE_LABELS[scope ?? 'global_xp'],
      current,
      next: null,
      expToNextRank: 0,
      progressToNextRank: 100,
      isFirstPlace: true,
      isFromSnapshot,
      nearbyEntries,
    };
  } else {
    const expToNextRank = Math.max(next.score - current.score + 1, 0);
    let progressToNextRank = 0;
    if (next.score > 0) {
      progressToNextRank = Math.min(Math.floor((current.score / next.score) * 100), 99);
    }
    summary = {
      scope: scope ?? 'global_xp',
      scopeLabel: LEADERBOARD_SCOPE_LABELS[scope ?? 'global_xp'],
      current,
      next,
      expToNextRank,
      progressToNextRank,
      isFirstPlace: false,
      isFromSnapshot,
      nearbyEntries,
    };
  }
  return { available: true, ...serializeRankingSummary(summary) };
}
