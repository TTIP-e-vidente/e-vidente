import { LeaderboardScope } from '../../leaderboard/leaderboard.types';

/**
 * Arma un enlace al juego con parámetros en la URL.
 * Ejemplo: https://itch.io/game?open=leaderboard&scope=global_xp
 */
export function buildAppDeepLink(baseUrl: string, params: Record<string, string>): string {
  const trimmedBase = baseUrl.trim();
  if (!trimmedBase) return '';

  const query = new URLSearchParams(params).toString();
  if (!query) return trimmedBase;

  const separator = trimmedBase.includes('?') ? '&' : '?';
  return `${trimmedBase}${separator}${query}`;
}

/** Enlace que abre el ranking del juego en un scope concreto. */
export function buildLeaderboardDeepLink(
  baseUrl: string,
  scope: LeaderboardScope = 'global_xp'
): string {
  return buildAppDeepLink(baseUrl, {
    open: 'leaderboard',
    scope
  });
}
