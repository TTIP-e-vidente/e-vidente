import { Restriction, VALID_RESTRICTIONS } from '../restrictions.ts';

// Scopes base + ranking por restricción (restriction:CELIAQUIA, etc.)
export type RestrictionLeaderboardScope = `restriction:${Restriction}`;
export type LeaderboardScope = 'global_xp' | 'streak' | RestrictionLeaderboardScope;

export const RESTRICTION_LEADERBOARD_SCOPES: RestrictionLeaderboardScope[] = VALID_RESTRICTIONS.map(
  (r) => `restriction:${r}` as RestrictionLeaderboardScope
);

export const LEADERBOARD_SCOPES: LeaderboardScope[] = [
  'global_xp',
  'streak',
  ...RESTRICTION_LEADERBOARD_SCOPES
];

export const LEADERBOARD_SCOPE_LABELS: Record<LeaderboardScope, string> = {
  global_xp: 'XP Global',
  streak: 'Mejor Racha',
  'restriction:CELIAQUIA': 'Celiaquía',
  'restriction:VEG': 'Veganismo',
  'restriction:VYG': 'Veganismo + Celiaquía',
  'restriction:KETO': 'Keto'
};

export function isRestrictionLeaderboardScope(scope: string): scope is RestrictionLeaderboardScope {
  return scope.startsWith('restriction:');
}

export function restrictionFromLeaderboardScope(scope: LeaderboardScope): Restriction | null {
  if (!isRestrictionLeaderboardScope(scope)) return null;
  const code = scope.slice('restriction:'.length);
  return (VALID_RESTRICTIONS as readonly string[]).includes(code) ? (code as Restriction) : null;
}

// ─── Filas de DB ──────────────────────────────────────────────────────────────

export interface LeaderboardSnapshotRow {
  id?: string;
  scope: string;
  user_id: string;
  username: string;
  display_name: string | null;
  avatar_key: string | null;
  score: string; // BIGINT llega como string desde pg
  rank: number;
  computed_at: Date;
  generation?: number;
}

export interface LeaderboardMeta {
  scope: LeaderboardScope;
  lastRefreshedAt: Date | null;
  rowCount: number;
  durationMs: number;
  currentGeneration: number;
  errorMessage: string | null;
}

// ─── Respuestas de servicio ───────────────────────────────────────────────────

export interface LeaderboardEntry {
  rank: number;
  userId: string;
  username: string;
  displayName: string | null;
  avatarKey: string | null;
  score: number;
}

export interface LeaderboardResult {
  scope: LeaderboardScope;
  scopeLabel: string;
  entries: LeaderboardEntry[];
  ownPosition: LeaderboardEntry | null; // incluido cuando include_self=true
  computedAt: Date | null;
  total: number;
  isStale: boolean;       // true si los datos vienen del stale-while-revalidate window
  isLiveFallback: boolean; // true si no había snapshot y se calculó en vivo
  pagination: {
    limit: number;
    offset: number;
    hasMore: boolean;
  };
}

export interface UserLeaderboardPosition {
  scope: LeaderboardScope;
  scopeLabel: string;
  rank: number | null;
  score: number | null;
  computedAt: Date | null;
}

// ─── Filtros de entrada ───────────────────────────────────────────────────────

export interface GetLeaderboardFilters {
  scope?: unknown;
  limit?: unknown;
  offset?: unknown;
  includeSelf?: boolean;
  userId?: string | null; // userId del request.user si está autenticado
}

export interface RefreshLeaderboardResult {
  scope: LeaderboardScope;
  rowsInserted: number;
  durationMs: number;
  error?: string;
}

// ─── Resumen competitivo del jugador (/me/summary) ────────────────────────────

/** Una entrada simplificada para el resumen competitivo (sin userId ni avatar). */
export interface RankingParticipant {
  rank: number;
  username: string;
  displayName: string | null;
  score: number;
}

/**
 * Contexto competitivo del jugador autenticado.
 * Responde a GET /leaderboard/me/summary.
 */
export interface RankingSummary {
  scope: LeaderboardScope;
  scopeLabel: string;
  /** Posición y score del jugador autenticado. */
  current: RankingParticipant;
  /** Jugador que está un puesto por encima. null si el jugador es primero. */
  next: RankingParticipant | null;
  /** EXP que necesita ganar para superar al jugador de arriba (0 si es primero). */
  expToNextRank: number;
  /**
   * Progreso en % entre el score del jugador y el score del siguiente rival.
   * Calculado como: (current.score / next.score) * 100, cap 99 si no lo superó.
   * 100 si el jugador es primero.
   */
  progressToNextRank: number;
  isFirstPlace: boolean;
  /** true si el resultado viene del snapshot; false si es fallback en vivo. */
  isFromSnapshot: boolean;
  /** Jugadores en rank ±N alrededor del jugador (incluye al propio). */
  nearbyEntries: LeaderboardEntry[];
}
