import { LeaderboardEntry, LeaderboardMeta, LeaderboardResult, RankingSummary, UserLeaderboardPosition } from './leaderboard.types';

// ─── Serialización de entries ─────────────────────────────────────────────────

export function serializeEntry(entry: LeaderboardEntry) {
  return {
    rank:         entry.rank,
    user_id:      entry.userId,
    username:     entry.username,
    display_name: entry.displayName,
    avatar_key:   entry.avatarKey,
    score:        entry.score
  };
}

export function serializeOwnPosition(pos: LeaderboardEntry | null) {
  if (!pos) return null;
  return {
    rank:         pos.rank,
    user_id:      pos.userId,
    username:     pos.username,
    display_name: pos.displayName,
    avatar_key:   pos.avatarKey,
    score:        pos.score
  };
}

// ─── Serialización del resultado completo ─────────────────────────────────────

export function serializeLeaderboardResult(result: LeaderboardResult) {
  return {
    scope:           result.scope,
    scope_label:     result.scopeLabel,
    total:           result.total,
    computed_at:     result.computedAt ?? null,
    is_live_fallback: result.isLiveFallback,
    is_stale:        result.isStale,
    pagination:      result.pagination,
    own_position:    serializeOwnPosition(result.ownPosition),
    entries:         result.entries.map(serializeEntry)
  };
}

// ─── Serialización de posiciones del usuario ──────────────────────────────────

export function serializeUserPosition(pos: UserLeaderboardPosition) {
  return {
    scope:       pos.scope,
    scope_label: pos.scopeLabel,
    rank:        pos.rank,
    score:       pos.score,
    computed_at: pos.computedAt ?? null
  };
}

// ─── Serialización de metadata del snapshot ───────────────────────────────────

export function serializeMeta(meta: LeaderboardMeta) {
  return {
    scope:              meta.scope,
    last_refreshed_at:  meta.lastRefreshedAt,
    row_count:          meta.rowCount,
    duration_ms:        meta.durationMs,
    current_generation: meta.currentGeneration,
    error_message:      meta.errorMessage,
    status:             meta.errorMessage ? 'error' : meta.lastRefreshedAt ? 'ok' : 'pending'
  };
}

// ─── Serialización de resumen competitivo ─────────────────────────────────────

function serializeParticipant(p: RankingSummary['current'] | NonNullable<RankingSummary['next']>) {
  return {
    rank:         p.rank,
    username:     p.username,
    display_name: p.displayName,
    score:        p.score
  };
}

export function serializeRankingSummary(summary: RankingSummary) {
  return {
    scope:                summary.scope,
    scope_label:          summary.scopeLabel,
    current:              serializeParticipant(summary.current),
    next:                 summary.next ? serializeParticipant(summary.next) : null,
    exp_to_next_rank:     summary.expToNextRank,
    progress_to_next_rank: summary.progressToNextRank,
    is_first_place:       summary.isFirstPlace,
    is_from_snapshot:     summary.isFromSnapshot,
    nearby_entries:       summary.nearbyEntries.map(serializeEntry)
  };
}
