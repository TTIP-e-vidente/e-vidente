/**
 * STREAK del MER.
 * profiles.streak_id → streaks.id
 */
import { PoolClient } from 'pg';
import * as profileRepository from '../profile/profile.repository';
import { StreakRow } from './streak.types';

const MS_PER_DAY = 86_400_000;

export function toDateOnly(value: Date | string | null | undefined): string | null {
  if (value == null) {
    return null;
  }
  if (typeof value === 'string') {
    // El cliente manda timestamps UTC sin sufijo 'Z' ("2026-06-10T22:33:44").
    // Date.parse los interpretaría en el timezone local del servidor y el día
    // podría correrse ±1: tomamos la fecha literal del string.
    const match = /^(\d{4}-\d{2}-\d{2})/.exec(value.trim());
    if (match) {
      return match[1];
    }
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      return null;
    }
    return parsed.toISOString().slice(0, 10);
  }
  if (Number.isNaN(value.getTime())) {
    return null;
  }
  // node-postgres parsea columnas `date` como Date a medianoche LOCAL del servidor;
  // toISOString() retrocedería un día en timezones con offset positivo.
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
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
  _activityDate?: string | null
): Promise<StreakRow> {
  const existing = await ensureStreak(client, userId, profileId);

  // Racha auto-curativa: en vez de incrementar un contador (sensible al orden
  // de llegada de los syncs), se recalcula desde los días UTC reales con
  // partidas completadas. Un run viejo que llega tarde REPARA la racha en
  // lugar de romperla, sin importar en qué batch o en qué orden se sincronice.
  const daysResult = await client.query<{ day: string }>(
    `
      SELECT DISTINCT
        to_char((COALESCE(finished_at, created_at) AT TIME ZONE 'UTC')::date, 'YYYY-MM-DD') AS day
      FROM games
      WHERE user_id = $1
        AND completed = true
        AND COALESCE(finished_at, created_at) > now() - interval '400 days'
      ORDER BY day DESC;
    `,
    [userId]
  );

  const days = daysResult.rows.map((row) => row.day);
  if (days.length === 0) {
    return existing;
  }

  const lastActivityDay = days[0];
  let newCount = 1;
  for (let i = 1; i < days.length; i++) {
    if (daysBetween(days[i - 1], days[i]) === 1) {
      newCount++;
    } else {
      break;
    }
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
    [existing.id, newCount, newBest, lastActivityDay]
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
