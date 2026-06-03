/**
 * STREAK del MER.
 *
 * Responsabilidad:
 * - Consultar y crear la racha diaria de un usuario.
 */
import { PoolClient } from 'pg';
import { StreakRow } from './streak.types';

export async function ensureStreak(
  client: PoolClient,
  userId: string,
  profileId: string
): Promise<StreakRow> {
  const result = await client.query<StreakRow>(
    `
      INSERT INTO player_streaks (user_id, profile_id, current_count, best_count, last_activity_day)
      VALUES ($1, $2, 1, 1, CURRENT_DATE)
      ON CONFLICT (profile_id)
      DO UPDATE SET
        current_count = GREATEST(player_streaks.current_count, 1),
        best_count = GREATEST(player_streaks.best_count, player_streaks.current_count, 1),
        last_activity_day = COALESCE(player_streaks.last_activity_day, CURRENT_DATE),
        updated_at = now()
      RETURNING id, user_id, profile_id, current_count, best_count, last_activity_day, updated_at;
    `,
    [userId, profileId]
  );

  return result.rows[0];
}

export async function getStreakByUserId(
  client: PoolClient,
  userId: string
): Promise<StreakRow | null> {
  const result = await client.query<StreakRow>(
    `
      SELECT id, user_id, profile_id, current_count, best_count, last_activity_day, updated_at
      FROM player_streaks
      WHERE user_id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}
