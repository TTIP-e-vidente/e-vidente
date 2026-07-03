/** Debe coincidir con BACKEND/src/config/migrations-meta.ts */
export const EXPECTED_MIGRATION_COUNT = 39;

export function isMigrationCountHealthy(applied: number): boolean {
  return applied >= EXPECTED_MIGRATION_COUNT;
}
