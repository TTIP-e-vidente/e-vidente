export const VALID_RESTRICTIONS = ['CELIAQUIA', 'VEG', 'VYG', 'KETO'] as const;
export type Restriction = (typeof VALID_RESTRICTIONS)[number];

export const TRACK_KEY_ALIASES: Record<string, Restriction> = {
  celiaquia: 'CELIAQUIA',
  veganismo: 'VEG',
  veganismo_celiaquia: 'VYG',
  cetogenica: 'KETO',
  keto: 'KETO',
};

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
