/** Cantidad de archivos .sql en BACKEND/migrations/ (actualizar al agregar migraciones). */
export const EXPECTED_MIGRATION_COUNT = 36;

export function isMigrationCountHealthy(count: number): boolean {
  return count >= EXPECTED_MIGRATION_COUNT;
}
