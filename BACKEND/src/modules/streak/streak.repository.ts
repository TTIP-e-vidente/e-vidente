/**
 * STREAK del MER.
 *
 * Responsabilidad:
 * - Consultar y crear la racha diaria de un usuario.
 * - Registrar actividad completada (misma logica que GameStreakTracker en Godot).
 */
import { PoolClient } from 'pg';
import { StreakRow } from './streak.types';

const MS_PER_DAY = 86_400_000;

function toDateOnly(value: Date | string | null | undefined): string | null {
  if (value == null) {
    return null;
  }
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed.toISOString().slice(0, 10);
}

function daysBetween(dateA: string, dateB: string): number {
  const unixA = Date.parse(`${dateA}T00:00:00.000Z`);
  const unixB = Date.parse(`${dateB}T00:00:00.000Z`);
  if (Number.isNaN(unixA) || Number.isNaN(unixB)) {
    return -1;
  }
  return Math.abs(Math.round((unixB - unixA) / MS_PER_DAY));
}

export async function ensureStreak(
  client: PoolClient,
  userId: string,
  profileId: string
): Promise<StreakRow> {
  const result = await client.query<StreakRow>(
    `
      INSERT INTO player_streaks (user_id, profile_id, current_count, best_count, last_activity_day)
      VALUES ($1, $2, 0, 0, NULL)
      ON CONFLICT (profile_id)
      DO UPDATE SET
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

export async function registerStreakActivity(
  client: PoolClient,
  userId: string,
  profileId: string,
  activityDate?: string | null
): Promise<StreakRow> {
  const today = toDateOnly(activityDate ?? new Date());
  if (!today) {
    return ensureStreak(client, userId, profileId);
  }

  const existing = await getStreakByUserId(client, userId);
  if (!existing) {
    const created = await client.query<StreakRow>(
      `
        INSERT INTO player_streaks (user_id, profile_id, current_count, best_count, last_activity_day)
        VALUES ($1, $2, 1, 1, $3::date)
        RETURNING id, user_id, profile_id, current_count, best_count, last_activity_day, updated_at;
      `,
      [userId, profileId, today]
    );
    return created.rows[0];
  }

  const lastDay = toDateOnly(existing.last_activity_day);
  let newCount = 1;
  if (lastDay === today) {
    newCount = Math.max(existing.current_count, 1);
  } else if (lastDay && daysBetween(lastDay, today) === 1) {
    newCount = existing.current_count + 1;
  }

  const newBest = Math.max(existing.best_count, newCount);
  const updated = await client.query<StreakRow>(
    `
      UPDATE player_streaks
      SET
        current_count = $2,
        best_count = $3,
        last_activity_day = $4::date,
        updated_at = now()
      WHERE user_id = $1
      RETURNING id, user_id, profile_id, current_count, best_count, last_activity_day, updated_at;
    `,
    [userId, newCount, newBest, today]
  );

  return updated.rows[0];
}
