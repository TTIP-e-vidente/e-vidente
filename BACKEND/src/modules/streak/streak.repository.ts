/**
 * STREAK del MER.
 * profiles.streak_id → streaks.id
 */
import { PoolClient } from 'pg';
import * as profileRepository from '../profile/profile.repository';
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

async function findStreakForUser(
  client: PoolClient,
  userId: string
): Promise<StreakRow | null> {
  const result = await client.query<StreakRow>(
    `
      SELECT
        s.id,
        p.user_id,
        p.id AS profile_id,
        s.current_count,
        s.best_count,
        s.last_activity_day,
        s.updated_at
      FROM profiles p
      JOIN streaks s ON s.id = p.streak_id
      WHERE p.user_id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function ensureStreak(
  client: PoolClient,
  userId: string,
  profileId: string
): Promise<StreakRow> {
  // Bloquea la fila del profile para serializar creaciones concurrentes del mismo usuario.
  await client.query(
    `SELECT id FROM profiles WHERE user_id = $1 FOR UPDATE`,
    [userId]
  );

  const existing = await findStreakForUser(client, userId);
  if (existing) {
    return existing;
  }

  const created = await client.query<{
    id: string;
    current_count: number;
    best_count: number;
    last_activity_day: Date | null;
    updated_at: Date;
  }>(
    `
      INSERT INTO streaks (current_count, best_count, last_activity_day)
      VALUES (0, 0, NULL)
      RETURNING id, current_count, best_count, last_activity_day, updated_at;
    `
  );

  const row = created.rows[0];
  await profileRepository.linkProfileToStreak(client, profileId, row.id);
  return {
    id: row.id,
    user_id: userId,
    profile_id: profileId,
    current_count: row.current_count,
    best_count: row.best_count,
    last_activity_day: row.last_activity_day,
    updated_at: row.updated_at
  };
}

export async function getStreakByUserId(
  client: PoolClient,
  userId: string
): Promise<StreakRow | null> {
  return findStreakForUser(client, userId);
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

  const existing = await ensureStreak(client, userId, profileId);
  const lastDay = toDateOnly(existing.last_activity_day);
  let newCount = 1;
  if (lastDay === today) {
    newCount = Math.max(existing.current_count, 1);
  } else if (lastDay && daysBetween(lastDay, today) === 1) {
    newCount = existing.current_count + 1;
  }

  const newBest = Math.max(existing.best_count, newCount);
  const updated = await client.query<{
    id: string;
    current_count: number;
    best_count: number;
    last_activity_day: Date | null;
    updated_at: Date;
  }>(
    `
      UPDATE streaks
      SET
        current_count = $2,
        best_count = $3,
        last_activity_day = $4::date,
        updated_at = now()
      WHERE id = $1
      RETURNING id, current_count, best_count, last_activity_day, updated_at;
    `,
    [existing.id, newCount, newBest, today]
  );

  const row = updated.rows[0];
  return {
    id: row.id,
    user_id: userId,
    profile_id: profileId,
    current_count: row.current_count,
    best_count: row.best_count,
    last_activity_day: row.last_activity_day,
    updated_at: row.updated_at
  };
}
