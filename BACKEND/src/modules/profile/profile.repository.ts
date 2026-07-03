import { PoolClient } from 'pg';
import { ProfileRow } from './profile.types';

export async function ensureProfile(
  client: PoolClient,
  userId: string,
  restriction: string | null = null
): Promise<ProfileRow> {
  const result = await client.query<ProfileRow>(
    `
      INSERT INTO profiles (user_id, current_restriction)
      VALUES ($1, $2)
      ON CONFLICT (user_id)
      DO UPDATE SET
        current_restriction = COALESCE(EXCLUDED.current_restriction, profiles.current_restriction),
        updated_at = now()
      RETURNING id, user_id, streak_id, exp_count, current_restriction, created_at, updated_at;
    `,
    [userId, restriction]
  );

  return result.rows[0];
}

export async function addProfileExp(
  client: PoolClient,
  userId: string,
  expToAdd: number,
  restriction: string
): Promise<ProfileRow> {
  const result = await client.query<ProfileRow>(
    `
      INSERT INTO profiles (user_id, exp_count, current_restriction)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id)
      DO UPDATE SET
        exp_count = profiles.exp_count + EXCLUDED.exp_count,
        current_restriction = EXCLUDED.current_restriction,
        updated_at = now()
      RETURNING id, user_id, streak_id, exp_count, current_restriction, created_at, updated_at;
    `,
    [userId, expToAdd, restriction]
  );

  return result.rows[0];
}

// Recalcula profiles.exp_count desde la fuente de verdad (la suma de total_exp de
// todas las restricciones del usuario). exp_count es un contador acumulado que
// addProfileExp() solo incrementa; sin este recálculo, un reset de progreso baja
// progress_restrictions.total_exp pero deja exp_count intacto, y el perfil y el
// leaderboard (que leen exp_count) seguirían mostrando el XP viejo.
export async function recomputeProfileExpFromRestrictions(
  client: PoolClient,
  userId: string
): Promise<ProfileRow | null> {
  const result = await client.query<ProfileRow>(
    `
      UPDATE profiles
      SET
        exp_count = COALESCE((
          SELECT SUM(total_exp)
          FROM progress_restrictions
          WHERE user_id = $1
        ), 0),
        updated_at = now()
      WHERE user_id = $1
      RETURNING id, user_id, streak_id, exp_count, current_restriction, created_at, updated_at;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function getProfileByUserId(
  client: PoolClient,
  userId: string
): Promise<ProfileRow | null> {
  const result = await client.query<ProfileRow>(
    `
      SELECT id, user_id, streak_id, exp_count, current_restriction, created_at, updated_at
      FROM profiles
      WHERE user_id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function linkProfileToStreak(
  client: PoolClient,
  profileId: string,
  streakId: string
): Promise<void> {
  await client.query(
    `
      UPDATE profiles
      SET streak_id = $2, updated_at = now()
      WHERE id = $1;
    `,
    [profileId, streakId]
  );
}
