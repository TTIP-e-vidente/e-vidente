import { PoolClient } from 'pg';
import { ProfileRow } from './profile.types';

export async function ensureProfile(
  client: PoolClient,
  userId: string,
  restriction: string | null = null
): Promise<ProfileRow> {
  const result = await client.query<ProfileRow>(
    `
      INSERT INTO player_profiles (user_id, current_restriction)
      VALUES ($1, $2)
      ON CONFLICT (user_id)
      DO UPDATE SET
        current_restriction = COALESCE(EXCLUDED.current_restriction, player_profiles.current_restriction),
        updated_at = now()
      RETURNING id, user_id, exp_count, current_restriction, created_at, updated_at;
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
      INSERT INTO player_profiles (user_id, exp_count, current_restriction)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id)
      DO UPDATE SET
        exp_count = player_profiles.exp_count + EXCLUDED.exp_count,
        current_restriction = EXCLUDED.current_restriction,
        updated_at = now()
      RETURNING id, user_id, exp_count, current_restriction, created_at, updated_at;
    `,
    [userId, expToAdd, restriction]
  );

  return result.rows[0];
}

export async function getProfileByUserId(
  client: PoolClient,
  userId: string
): Promise<ProfileRow | null> {
  const result = await client.query<ProfileRow>(
    `
      SELECT id, user_id, exp_count, current_restriction, created_at, updated_at
      FROM player_profiles
      WHERE user_id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}
