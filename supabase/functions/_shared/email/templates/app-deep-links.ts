/** Generado por sync-email-templates-edge.cjs — no editar a mano. */
export function buildAppDeepLink(baseUrl: string, params: Record<string, string>): string {
  const trimmedBase = baseUrl.trim();
  if (!trimmedBase) return '';

  const query = new URLSearchParams(params).toString();
  if (!query) return trimmedBase;

  const separator = trimmedBase.includes('?') ? '&' : '?';
  return `${trimmedBase}${separator}${query}`;
}

export function buildLeaderboardDeepLink(
  baseUrl: string,
  scope = 'global_xp',
): string {
  return buildAppDeepLink(baseUrl, {
    open: 'leaderboard',
    scope,
  });
}
