/**
 * Claves de restricciones alimentarias válidas en el sistema.
 * Deben coincidir con validRestrictions en validators.ts y con
 * los valores en restriction_node_config (DB).
 *
 * Los conteos de nodos por restricción viven en la tabla
 * restriction_node_config (migración 010), populada desde los
 * JSON de mapa de Godot (ej: celiaquia_mapa.json).
 */
export const VALID_RESTRICTIONS = ['CELIAQUIA', 'VEG', 'VYG', 'KETO'] as const;
export type Restriction = (typeof VALID_RESTRICTIONS)[number];

/** Claves de pista del juego (Godot track_key) → código backend. */
export const TRACK_KEY_ALIASES: Record<string, Restriction> = {
  celiaquia: 'CELIAQUIA',
  veganismo: 'VEG',
  veganismo_celiaquia: 'VYG',
  cetogenica: 'KETO',
  keto: 'KETO'
};

/**
 * Normaliza restriction desde código backend o track_key del cliente Godot.
 * Retorna undefined si no es reconocible.
 */
export function normalizeRestrictionInput(value: unknown): Restriction | undefined {
  if (typeof value !== 'string') return undefined;

  const trimmed = value.trim();
  if (!trimmed) return undefined;

  const upper = trimmed.toUpperCase();
  if ((VALID_RESTRICTIONS as readonly string[]).includes(upper)) {
    return upper as Restriction;
  }

  const alias = TRACK_KEY_ALIASES[trimmed.toLowerCase()];
  return alias ?? undefined;
}
