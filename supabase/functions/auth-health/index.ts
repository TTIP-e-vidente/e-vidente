import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import { AuthError, requireAnonKey } from '../_shared/jwt.ts';
import { withDb } from '../_shared/db.ts';
import {
  EXPECTED_MIGRATION_COUNT,
  isMigrationCountHealthy,
} from '../_shared/migrations-meta.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) {
    return cors;
  }

  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);

    const info = await withDb(async (db) => {
      const dbInfo = await db.queryObject<{ current_database: string; current_user: string }>(
        'SELECT current_database(), current_user;',
      );
      const row = dbInfo.rows[0];
      const migrationCount = await db.queryObject<{ count: string }>(
        `
          SELECT COUNT(*)::text AS count
          FROM schema_migrations;
        `,
      );
      const applied = Number.parseInt(migrationCount.rows[0]?.count ?? '0', 10);
      return {
        current_database: row?.current_database ?? '',
        current_user: row?.current_user ?? '',
        applied,
      };
    });

    return jsonResponse({
      status: 'ok',
      source: 'supabase-edge',
      database: info.current_database,
      user: info.current_user,
      remote: true,
      migrations: {
        applied: info.applied,
        expected: EXPECTED_MIGRATION_COUNT,
        healthy: isMigrationCountHealthy(info.applied),
      },
    });
  } catch (error) {
    if (error instanceof AuthError) {
      return errorResponse(401, error.message);
    }
    console.error('[auth-health]', error);
    return errorResponse(503, 'Database unavailable');
  }
});
