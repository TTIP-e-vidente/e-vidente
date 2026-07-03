/**
 * STREAK del MER.
 * profiles.streak_id → streaks.id
 */
import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';
import * as profileRepository from './profile.ts';
import { StreakRow } from '../types/player.ts';

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
  client: Client,
  userId: string
): Promise<StreakRow | null> {
  const result = await client.queryObject<StreakRow>(
    `
      SELECT
        s.id,
        p.user_id,
        p.id AS profile_id,
        s.current_count,
        s.best_count,
        s.last_activity_day,
        s.last_activity_at,
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
  client: Client,
  userId: string,
  profileId: string
): Promise<StreakRow> {
  // Bloquea la fila del profile para serializar creaciones concurrentes del mismo usuario.
  await client.queryObject(
    `SELECT id FROM profiles WHERE user_id = $1 FOR UPDATE`,
    [userId]
  );

  const existing = await findStreakForUser(client, userId);
  if (existing) {
    return existing;
  }

  const created = await client.queryObject<{
    id: string;
    current_count: number;
    best_count: number;
    last_activity_day: Date | null;
    last_activity_at: Date | null;
    updated_at: Date;
  }>(
    `
      INSERT INTO streaks (current_count, best_count, last_activity_day)
      VALUES (0, 0, NULL)
      RETURNING id, current_count, best_count, last_activity_day, last_activity_at, updated_at;
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
    last_activity_at: row.last_activity_at,
    updated_at: row.updated_at
  };
}

export async function getStreakByUserId(
  client: Client,
  userId: string
): Promise<StreakRow | null> {
  return findStreakForUser(client, userId);
}

export async function registerStreakActivity(
  client: Client,
  userId: string,
  profileId: string,
  _activityDate?: string | null
): Promise<StreakRow> {
  const existing = await ensureStreak(client, userId, profileId);

  // Racha auto-curativa: en vez de incrementar un contador (sensible al orden
  // de llegada de los syncs), se recalcula desde los días reales con partidas
  // completadas. Un run viejo que llega tarde REPARA la racha en lugar de
  // romperla, sin importar en qué batch o en qué orden se sincronice.
  // El día relevante es el calendario LOCAL del jugador (games.local_day,
  // que manda el cliente); para partidas viejas sin local_day se cae al día UTC.
  const daysResult = await client.queryObject<{ day: string; last_at: Date }>(
    `
      SELECT
        to_char(
          COALESCE(local_day, (COALESCE(finished_at, created_at) AT TIME ZONE 'UTC')::date),
          'YYYY-MM-DD'
        ) AS day,
        MAX(COALESCE(finished_at, created_at)) AS last_at
      FROM games
      WHERE user_id = $1
        AND completed = true
        AND COALESCE(finished_at, created_at) > now() - interval '400 days'
      GROUP BY 1
      ORDER BY day DESC;
    `,
    [userId]
  );

  const days = daysResult.rows.map((row) => row.day);
  if (days.length === 0) {
    return existing;
  }

  const lastActivityDay = days[0];
  let lastActivityAt: Date | null = null;
  for (const row of daysResult.rows) {
    if (lastActivityAt === null || row.last_at > lastActivityAt) {
      lastActivityAt = row.last_at;
    }
  }
  let gamesCount = 1;
  for (let i = 1; i < days.length; i++) {
    if (daysBetween(days[i - 1], days[i]) === 1) {
      gamesCount++;
    } else {
      break;
    }
  }

  // El historial de `games`/`history_games` se borra al resetear el progreso
  // de un jugador (ver resetProgressCounters + deleteNodeHistoryByProgressId,
  // que hace cascade sobre games.history_id). La racha diaria es un hábito
  // independiente del avance de mapa y no debería perderse por eso: si el
  // estado ya persistido en `streaks` describe una racha viva y más larga que
  // la reconstruible desde `games` (podado por un reset), se preserva/extiende
  // ese estado en vez de recalcularlo desde cero.
  const existingDay = toDateOnly(existing.last_activity_day);
  let finalCount = gamesCount;
  let finalDay = lastActivityDay;
  if (existingDay) {
    if (existingDay === lastActivityDay) {
      finalCount = Math.max(gamesCount, existing.current_count);
    } else if (existingDay < lastActivityDay && daysBetween(existingDay, lastActivityDay) === 1) {
      finalCount = Math.max(gamesCount, existing.current_count + 1);
    } else if (existingDay > lastActivityDay) {
      // El estado persistido ya es más reciente que lo reconstruible desde
      // games (no debería pasar en el flujo normal); no hay que retroceder.
      finalCount = existing.current_count;
      finalDay = existingDay;
    }
    // Si el hueco es mayor a 1 día y existingDay < lastActivityDay, la racha
    // vieja ya había expirado: no hay nada que preservar, gana el cálculo
    // desde games (reconcileExpiredStreaks se ocupa del aviso de pérdida).
  }

  const newBest = Math.max(existing.best_count, finalCount);
  const updated = await client.queryObject<{
    id: string;
    current_count: number;
    best_count: number;
    last_activity_day: Date | null;
    last_activity_at: Date | null;
    updated_at: Date;
  }>(
    `
      UPDATE streaks
      SET
        current_count = $2,
        best_count = $3,
        last_activity_day = $4::date,
        last_activity_at = $5,
        updated_at = now()
      WHERE id = $1
      RETURNING id, current_count, best_count, last_activity_day, last_activity_at, updated_at;
    `,
    [existing.id, finalCount, newBest, finalDay, lastActivityAt]
  );

  const row = updated.rows[0];
  return {
    id: row.id,
    user_id: userId,
    profile_id: profileId,
    current_count: row.current_count,
    best_count: row.best_count,
    last_activity_day: row.last_activity_day,
    last_activity_at: row.last_activity_at,
    updated_at: row.updated_at
  };
}
