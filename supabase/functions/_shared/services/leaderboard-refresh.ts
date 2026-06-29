import {
  LEADERBOARD_SCOPES,
  restrictionFromLeaderboardScope,
  type LeaderboardScope,
  type RefreshLeaderboardResult,
} from '../leaderboard/types.ts';
import { VALID_RESTRICTIONS } from '../restrictions.ts';
import * as leaderboardRepository from '../leaderboard/repository.ts';

const refreshingScopes = new Set<LeaderboardScope>();

function runInBackground(work: Promise<unknown>): void {
  const runtime = (globalThis as { EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void } })
    .EdgeRuntime;
  if (runtime?.waitUntil) {
    runtime.waitUntil(work);
    return;
  }
  void work;
}

function scopesForProgressSave(restriction: string, completed: boolean): LeaderboardScope[] {
  const scopes: LeaderboardScope[] = ['global_xp'];
  if (completed) {
    scopes.push('streak');
  }
  const code = restriction.trim().toUpperCase();
  if ((VALID_RESTRICTIONS as readonly string[]).includes(code)) {
    scopes.push(`restriction:${code}` as LeaderboardScope);
  }
  return scopes;
}

async function refreshScopes(scopes: LeaderboardScope[]): Promise<void> {
  await Promise.all(
    scopes.map((scope) =>
      refreshLeaderboard(scope).catch((err) => {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`[leaderboard] post-progress refresh ${scope} failed: ${msg}`);
      }),
    ),
  );
}

/**
 * Dispara refresh en background tras guardar progreso (scopes relevantes, en paralelo).
 */
export function triggerLeaderboardRefreshAfterProgress(
  restriction: string,
  completed: boolean,
): void {
  const scopes = scopesForProgressSave(restriction, completed);
  runInBackground(refreshScopes(scopes));
}

/**
 * Refresh de todos los scopes (cron / warm-up).
 */
export function triggerLeaderboardRefresh(): void {
  runInBackground(refreshScopes([...LEADERBOARD_SCOPES]));
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
