const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

export function isValidEmail(value: unknown): value is string {
  return typeof value === 'string' && emailPattern.test(value.trim());
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

export function formatBirthDate(value: Date | string | null | undefined): string | null {
  if (value == null) return null;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return /^\d{4}-\d{2}-\d{2}$/.test(trimmed) ? trimmed : null;
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  return null;
}

export function parseBirthDateInput(value: unknown): string | null | undefined {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return undefined;
  const [yearText, monthText, dayText] = trimmed.split('-');
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return undefined;
  }
  const today = new Date();
  const todayUtc = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  if (parsed.getTime() > todayUtc) return undefined;
  return trimmed;
}
