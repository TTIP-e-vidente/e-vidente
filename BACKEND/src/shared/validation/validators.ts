const validRestrictions = new Set(['CELIAQUIA', 'VEG', 'VYG', 'KETO']);
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

export function isValidEmail(value: unknown): value is string {
  return typeof value === 'string' && emailPattern.test(value.trim());
}

export function isPositiveNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0;
}

export function isAllowedRestriction(value: unknown): value is string {
  return typeof value === 'string' && validRestrictions.has(value.trim().toUpperCase());
}

export function parseNumberOrDefault(value: unknown, defaultValue: number): number {
  if (value === undefined || value === null) {
    return defaultValue;
  }

  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return Number.NaN;
  }

  return value;
}
