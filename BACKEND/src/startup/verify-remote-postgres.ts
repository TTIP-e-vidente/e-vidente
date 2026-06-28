import { query } from '../config/database';
import { isRemotePostgres } from '../config/postgresPoolConfig';
import { getAppliedMigrationCount } from '../modules/health/health.repository';
import { isMigrationCountHealthy } from '../config/migrations-meta';

export async function verifyRemotePostgresOnStartup(): Promise<void> {
  if (!isRemotePostgres() || process.env.NODE_ENV === 'test') {
    return;
  }

  const host = process.env.POSTGRES_HOST ?? '?';
  const user = process.env.POSTGRES_USER ?? '?';

  await query('SELECT 1');
  const migrationCount = await getAppliedMigrationCount();

  if (!isMigrationCountHealthy(migrationCount)) {
    throw new Error(
      `[postgres] Supabase conectado (${user}@${host}) pero faltan migraciones (${migrationCount}). Corré: npm run deploy:migrate`
    );
  }

  console.log(`[postgres] Supabase OK — ${user}@${host} · migraciones ${migrationCount}`);
}
