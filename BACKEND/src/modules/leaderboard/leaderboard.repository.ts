import { pool, query } from '../../config/database';
import { Restriction } from '../../config/restrictions';
import {
  LeaderboardEntry,
  LeaderboardMeta,
  LeaderboardScope,
  LeaderboardSnapshotRow
} from './leaderboard.types';

const AVATAR_KEY_SQL = `CASE WHEN img.data IS NOT NULL THEN img.id::text ELSE NULL END`;

function rowToEntry(row: LeaderboardSnapshotRow): LeaderboardEntry {
  return {
    rank: row.rank,
    userId: row.user_id,
    username: row.username,
    displayName: row.display_name ?? null,
    avatarKey: row.avatar_key ?? null,
    score: parseInt(String(row.score), 10)
  };
}

function dedupeEntries(entries: LeaderboardEntry[]): LeaderboardEntry[] {
  const seenUsers = new Set<string>();
  const result: LeaderboardEntry[] = [];
  for (const entry of entries) {
    if (!entry.userId?.trim()) continue;
    if (entry.score <= 0) continue;
    // Dedupe SOLO por usuario. NO deduplicamos por rank: RANK() asigna el mismo rank
    // a jugadores empatados en score, así que filtrar por rank repetido escondería
    // a todos los empatados menos uno (bug que dejaba el leaderboard con una sola fila).
    if (seenUsers.has(entry.userId)) continue;
    seenUsers.add(entry.userId);
    result.push(entry);
  }
  return result.sort((a, b) => a.rank - b.rank);
}

/** Solo filas de la generación activa (evita snapshots viejos mezclados). */
const SNAPSHOT_CURRENT_GEN_SQL = `
  FROM leaderboard_snapshots s
  INNER JOIN leaderboard_meta m ON m.scope = s.scope AND s.generation = m.current_generation
`;

async function doRefresh(
  scope: LeaderboardScope,
  insertSql: string,
  insertParams: unknown[],
  startedAt: Date
): Promise<number> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const genResult = await client.query<{ current_generation: number }>(
      `SELECT current_generation FROM leaderboard_meta WHERE scope = $1 FOR UPDATE`,
      [scope]
    );
    const nextGen = (genResult.rows[0]?.current_generation ?? 0) + 1;

    // INSERT nueva generación — los lectores aún ven la vieja
    const insertResult = await client.query(insertSql, [...insertParams, nextGen]);
    const rowsInserted = insertResult.rowCount ?? 0;

    // Actualizar meta ANTES de borrar — a partir de aquí los lectores verán la nueva
    const durationMs = Date.now() - startedAt.getTime();
    await client.query(
      `
        UPDATE leaderboard_meta
        SET
          last_refreshed_at  = now(),
          row_count          = $2,
          duration_ms        = $3,
          current_generation = $1,
          error_message      = NULL
        WHERE scope = $4
      `,
      [nextGen, rowsInserted, durationMs, scope]
    );

    // Borrar generaciones viejas — ahora es seguro
    await client.query(
      `DELETE FROM leaderboard_snapshots WHERE scope = $1 AND generation < $2`,
      [scope, nextGen]
    );

    await client.query('COMMIT');
    return rowsInserted;
  } catch (error) {
    await client.query('ROLLBACK');
    // Registrar error best-effort (no tiene que fallar el throw principal)
    void query(
      `UPDATE leaderboard_meta SET error_message = $1 WHERE scope = $2`,
      [error instanceof Error ? error.message.slice(0, 500) : String(error), scope]
    ).catch(() => { /* best-effort */ });
    throw error;
  } finally {
    client.release();
  }
}

export async function refreshGlobalXpSnapshot(startedAt: Date): Promise<number> {
  return doRefresh(
    'global_xp',
    `
      INSERT INTO leaderboard_snapshots
        (scope, user_id, username, display_name, avatar_key, score, rank, computed_at, generation)
      SELECT
        'global_xp'                                                   AS scope,
        u.id                                                          AS user_id,
        u.username                                                    AS username,
        u.name                                                        AS display_name,
        ${AVATAR_KEY_SQL}                                             AS avatar_key,
        COALESCE(p.exp_count, 0)                                      AS score,
        RANK() OVER (ORDER BY COALESCE(p.exp_count, 0) DESC)::integer AS rank,
        now()                                                         AS computed_at,
        $1                                                            AS generation
      FROM users u
      LEFT JOIN profiles p  ON p.user_id  = u.id
      LEFT JOIN images   img ON img.user_id = u.id
      WHERE COALESCE(p.exp_count, 0) > 0
    `,
    [],
    startedAt
  );
}

export async function refreshStreakSnapshot(startedAt: Date): Promise<number> {
  return doRefresh(
    'streak',
    `
      INSERT INTO leaderboard_snapshots
        (scope, user_id, username, display_name, avatar_key, score, rank, computed_at, generation)
      SELECT
        'streak'                                                         AS scope,
        u.id                                                             AS user_id,
        u.username                                                       AS username,
        u.name                                                           AS display_name,
        ${AVATAR_KEY_SQL}                                                AS avatar_key,
        COALESCE(s.best_count, 0)                                        AS score,
        RANK() OVER (ORDER BY COALESCE(s.best_count, 0) DESC)::integer   AS rank,
        now()                                                            AS computed_at,
        $1                                                               AS generation
      FROM users u
      LEFT JOIN profiles p  ON p.user_id   = u.id
      LEFT JOIN streaks  s  ON s.id        = p.streak_id
      LEFT JOIN images   img ON img.user_id = u.id
      WHERE COALESCE(s.best_count, 0) > 0
    `,
    [],
    startedAt
  );
}

export async function refreshRestrictionSnapshot(
  restriction: Restriction,
  startedAt: Date
): Promise<number> {
  const scope = `restriction:${restriction}`;
  return doRefresh(
    scope as LeaderboardScope,
    `
      INSERT INTO leaderboard_snapshots
        (scope, user_id, username, display_name, avatar_key, score, rank, computed_at, generation)
      SELECT
        '${scope}'                                                    AS scope,
        u.id                                                          AS user_id,
        u.username                                                    AS username,
        u.name                                                        AS display_name,
        ${AVATAR_KEY_SQL}                                             AS avatar_key,
        COALESCE(pr.total_exp, 0)                                     AS score,
        RANK() OVER (ORDER BY COALESCE(pr.total_exp, 0) DESC)::integer AS rank,
        now()                                                         AS computed_at,
        $1                                                            AS generation
      FROM users u
      INNER JOIN profiles p ON p.user_id = u.id
      INNER JOIN progress_restrictions pr ON pr.profile_id = p.id AND pr.restriction = '${restriction}'
      LEFT JOIN images img ON img.user_id = u.id
      WHERE COALESCE(pr.total_exp, 0) > 0
    `,
    [],
    startedAt
  );
}

// ─── Meta ──────────────────────────────────────────────────────────────────────

export async function getMeta(scope: LeaderboardScope): Promise<LeaderboardMeta | null> {
  const result = await query<{
    scope: string;
    last_refreshed_at: Date | null;
    row_count: number;
    duration_ms: number;
    current_generation: number;
    error_message: string | null;
  }>(
    `SELECT scope, last_refreshed_at, row_count, duration_ms, current_generation, error_message
     FROM leaderboard_meta WHERE scope = $1`,
    [scope]
  );
  const row = result.rows[0];
  if (!row) return null;
  return {
    scope: row.scope as LeaderboardScope,
    lastRefreshedAt: row.last_refreshed_at,
    rowCount: row.row_count,
    durationMs: row.duration_ms,
    currentGeneration: row.current_generation,
    errorMessage: row.error_message
  };
}

export async function getAllMeta(): Promise<LeaderboardMeta[]> {
  const result = await query<{
    scope: string;
    last_refreshed_at: Date | null;
    row_count: number;
    duration_ms: number;
    current_generation: number;
    error_message: string | null;
  }>(
    `SELECT scope, last_refreshed_at, row_count, duration_ms, current_generation, error_message
     FROM leaderboard_meta ORDER BY scope`
  );
  return result.rows.map((row) => ({
    scope: row.scope as LeaderboardScope,
    lastRefreshedAt: row.last_refreshed_at,
    rowCount: row.row_count,
    durationMs: row.duration_ms,
    currentGeneration: row.current_generation,
    errorMessage: row.error_message
  }));
}

// ─── Lectura desde snapshot ───────────────────────────────────────────────────

/**
 * Top-N del leaderboard desde snapshot.
 * No incluye COUNT(*) — usa meta.row_count que ya tenemos cached.
 */
export async function getTopEntries(
  scope: LeaderboardScope,
  limit: number,
  offset: number
): Promise<LeaderboardEntry[]> {
  const safeLimit  = Math.max(1, Math.min(limit, 200));
  const safeOffset = Math.max(0, offset);

  const result = await query<LeaderboardSnapshotRow>(
    `
      SELECT s.rank, s.user_id, s.username, s.display_name, s.avatar_key, s.score, s.computed_at
      ${SNAPSHOT_CURRENT_GEN_SQL}
      WHERE s.scope = $1 AND s.score > 0
      ORDER BY s.rank ASC
      LIMIT $2 OFFSET $3
    `,
    [scope, safeLimit, safeOffset]
  );

  return dedupeEntries(result.rows.map(rowToEntry));
}

/**
 * Posición + datos completos del usuario en el snapshot.
 * Incluye username/displayName/avatarKey para que ownPosition esté completo.
 */
export async function getUserRankInSnapshot(
  scope: LeaderboardScope,
  userId: string
): Promise<LeaderboardEntry & { computedAt: Date } | null> {
  const result = await query<LeaderboardSnapshotRow & { computed_at: Date }>(
    `
      SELECT s.rank, s.user_id, s.username, s.display_name, s.avatar_key, s.score, s.computed_at
      ${SNAPSHOT_CURRENT_GEN_SQL}
      WHERE s.scope = $1 AND s.user_id = $2 AND s.score > 0
      ORDER BY s.generation DESC
      LIMIT 1
    `,
    [scope, userId]
  );

  const row = result.rows[0];
  if (!row) return null;
  return {
    ...rowToEntry(row),
    computedAt: row.computed_at
  };
}

// ─── Fallback en vivo (cuando no existe snapshot) ────────────────────────────

const LIVE_SELECT_GLOBAL_XP = `
  SELECT
    RANK() OVER (ORDER BY COALESCE(p.exp_count, 0) DESC)::integer AS rank,
    u.id          AS user_id,
    u.username    AS username,
    u.name        AS display_name,
    CASE WHEN img.data IS NOT NULL THEN img.id::text ELSE NULL END AS avatar_key,
    COALESCE(p.exp_count, 0) AS score
  FROM users u
  LEFT JOIN profiles p  ON p.user_id  = u.id
  LEFT JOIN images   img ON img.user_id = u.id
  ORDER BY score DESC
  LIMIT $1 OFFSET $2
`;

const LIVE_SELECT_STREAK = `
  SELECT
    RANK() OVER (ORDER BY COALESCE(s.best_count, 0) DESC)::integer AS rank,
    u.id          AS user_id,
    u.username    AS username,
    u.name        AS display_name,
    CASE WHEN img.data IS NOT NULL THEN img.id::text ELSE NULL END AS avatar_key,
    COALESCE(s.best_count, 0) AS score
  FROM users u
  LEFT JOIN profiles p  ON p.user_id  = u.id
  LEFT JOIN streaks  s  ON s.id       = p.streak_id
  LEFT JOIN images   img ON img.user_id = u.id
  ORDER BY score DESC
  LIMIT $1 OFFSET $2
`;

type LiveRow = {
  rank: string; user_id: string; username: string;
  display_name: string | null; avatar_key: string | null; score: string;
};

function liveRowToEntry(r: LiveRow): LeaderboardEntry {
  return {
    rank: parseInt(String(r.rank), 10),
    userId: r.user_id,
    username: r.username,
    displayName: r.display_name ?? null,
    avatarKey: r.avatar_key ?? null,
    score: parseInt(String(r.score), 10)
  };
}

export async function getLiveGlobalXpEntries(limit: number, offset: number): Promise<LeaderboardEntry[]> {
  const result = await query<LiveRow>(LIVE_SELECT_GLOBAL_XP, [
    Math.max(1, Math.min(limit, 200)),
    Math.max(0, offset)
  ]);
  return result.rows.map(liveRowToEntry);
}

export async function getLiveStreakEntries(limit: number, offset: number): Promise<LeaderboardEntry[]> {
  const result = await query<LiveRow>(LIVE_SELECT_STREAK, [
    Math.max(1, Math.min(limit, 200)),
    Math.max(0, offset)
  ]);
  return result.rows.map(liveRowToEntry);
}

export async function getLiveRestrictionEntries(
  restriction: Restriction,
  limit: number,
  offset: number
): Promise<LeaderboardEntry[]> {
  const sql = `
    SELECT
      RANK() OVER (ORDER BY COALESCE(pr.total_exp, 0) DESC)::integer AS rank,
      u.id          AS user_id,
      u.username    AS username,
      u.name        AS display_name,
      CASE WHEN img.data IS NOT NULL THEN img.id::text ELSE NULL END AS avatar_key,
      COALESCE(pr.total_exp, 0) AS score
    FROM users u
    INNER JOIN profiles p ON p.user_id = u.id
    INNER JOIN progress_restrictions pr ON pr.profile_id = p.id AND pr.restriction = $3
    LEFT JOIN images img ON img.user_id = u.id
    ORDER BY score DESC
    LIMIT $1 OFFSET $2
  `;
  const result = await query<LiveRow>(sql, [
    Math.max(1, Math.min(limit, 200)),
    Math.max(0, offset),
    restriction
  ]);
  return result.rows.map(liveRowToEntry);
}

/**
 * Posición en vivo del usuario (cuando no hay snapshot).
 * Usa una subquery de RANK para no escanear toda la tabla.
 */
export async function getLiveUserRank(
  scope: LeaderboardScope,
  userId: string
): Promise<{ rank: number; score: number } | null> {
  let sql: string;
  let params: unknown[] = [userId];

  if (scope === 'global_xp') {
    sql = `
      WITH ranked AS (
        SELECT
          u.id AS user_id,
          RANK() OVER (ORDER BY COALESCE(p.exp_count, 0) DESC)::integer AS rank,
          COALESCE(p.exp_count, 0) AS score
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
      )
      SELECT rank, score FROM ranked WHERE user_id = $1 LIMIT 1
    `;
  } else if (scope === 'streak') {
    sql = `
      WITH ranked AS (
        SELECT
          u.id AS user_id,
          RANK() OVER (ORDER BY COALESCE(s.best_count, 0) DESC)::integer AS rank,
          COALESCE(s.best_count, 0) AS score
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
        LEFT JOIN streaks  s ON s.id = p.streak_id
      )
      SELECT rank, score FROM ranked WHERE user_id = $1 LIMIT 1
    `;
  } else if (scope.startsWith('restriction:')) {
    const restriction = scope.slice('restriction:'.length);
    sql = `
      WITH ranked AS (
        SELECT
          u.id AS user_id,
          RANK() OVER (ORDER BY COALESCE(pr.total_exp, 0) DESC)::integer AS rank,
          COALESCE(pr.total_exp, 0) AS score
        FROM users u
        INNER JOIN profiles p ON p.user_id = u.id
        INNER JOIN progress_restrictions pr ON pr.profile_id = p.id AND pr.restriction = $2
      )
      SELECT rank, score FROM ranked WHERE user_id = $1 LIMIT 1
    `;
    params = [userId, restriction];
  } else {
    return null;
  }

  const result = await query<{ rank: number; score: string }>(sql, params);
  const row = result.rows[0];
  if (!row) return null;
  return { rank: row.rank, score: parseInt(String(row.score), 10) };
}

// ─── Entradas cercanas al jugador (±N ranks) ───────────────────────────────────

/**
 * Devuelve las filas del ranking en un rango ±radius alrededor del jugador.
 * Prioriza snapshot; si no hay filas, usa fallback en vivo.
 */
export async function getNearbyEntries(
  userId: string,
  scope: LeaderboardScope,
  radius: number = 2,
  generation: number | null = null
): Promise<LeaderboardEntry[]> {
  const safeRadius = Math.max(0, Math.min(radius, 10));

  // Si se pasa una generación pinneada (misma que usó getUserRankingContext),
  // se filtra directo por ella en vez de resolver "current_generation" de nuevo:
  // evita que un refresh en background la cambie entre ambas consultas.
  const genFilterSql = generation !== null ? 'FROM leaderboard_snapshots s' : SNAPSHOT_CURRENT_GEN_SQL;
  const genWhereSql = generation !== null ? 'AND s.generation = $4' : '';
  const params = generation !== null
    ? [userId, scope, safeRadius, generation]
    : [userId, scope, safeRadius];

  const snapshotResult = await query<LeaderboardSnapshotRow>(
    `
      WITH player AS (
        SELECT s.rank
        ${genFilterSql}
        WHERE s.scope = $2 AND s.user_id = $1 AND s.score > 0 ${genWhereSql}
        LIMIT 1
      )
      SELECT s.rank, s.user_id, s.username, s.display_name, s.avatar_key, s.score, s.computed_at
      ${genFilterSql}
      INNER JOIN player p ON true
      WHERE s.scope = $2
        AND s.score > 0
        AND s.rank BETWEEN p.rank - $3 AND p.rank + $3
        ${genWhereSql}
      ORDER BY s.rank ASC
    `,
    params
  );

  if (snapshotResult.rows.length > 0) {
    return dedupeEntries(snapshotResult.rows.map(rowToEntry));
  }

  const liveRank = await getLiveUserRank(scope, userId);
  if (!liveRank) return [];

  return dedupeEntries(await getLiveNearbyEntries(scope, liveRank.rank, safeRadius));
}

async function getLiveNearbyEntries(
  scope: LeaderboardScope,
  centerRank: number,
  radius: number
): Promise<LeaderboardEntry[]> {
  const minRank = Math.max(1, centerRank - radius);
  const maxRank = centerRank + radius;

  let rankedSql: string;
  let params: unknown[] = [minRank, maxRank];

  if (scope === 'global_xp') {
    rankedSql = `
      WITH ranked AS (
        SELECT
          RANK() OVER (ORDER BY COALESCE(p.exp_count, 0) DESC, u.id ASC)::integer AS rank,
          u.id          AS user_id,
          u.username    AS username,
          u.name        AS display_name,
          ${AVATAR_KEY_SQL} AS avatar_key,
          COALESCE(p.exp_count, 0) AS score
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
        LEFT JOIN images img ON img.user_id = u.id
      )
      SELECT rank, user_id, username, display_name, avatar_key, score
      FROM ranked
      WHERE rank BETWEEN $1 AND $2
      ORDER BY rank ASC
    `;
  } else if (scope === 'streak') {
    rankedSql = `
      WITH ranked AS (
        SELECT
          RANK() OVER (ORDER BY COALESCE(s.best_count, 0) DESC, u.id ASC)::integer AS rank,
          u.id          AS user_id,
          u.username    AS username,
          u.name        AS display_name,
          ${AVATAR_KEY_SQL} AS avatar_key,
          COALESCE(s.best_count, 0) AS score
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
        LEFT JOIN streaks  s ON s.id = p.streak_id
        LEFT JOIN images img ON img.user_id = u.id
      )
      SELECT rank, user_id, username, display_name, avatar_key, score
      FROM ranked
      WHERE rank BETWEEN $1 AND $2
      ORDER BY rank ASC
    `;
  } else if (scope.startsWith('restriction:')) {
    const restriction = scope.slice('restriction:'.length);
    rankedSql = `
      WITH ranked AS (
        SELECT
          RANK() OVER (ORDER BY COALESCE(pr.total_exp, 0) DESC, u.id ASC)::integer AS rank,
          u.id          AS user_id,
          u.username    AS username,
          u.name        AS display_name,
          ${AVATAR_KEY_SQL} AS avatar_key,
          COALESCE(pr.total_exp, 0) AS score
        FROM users u
        INNER JOIN profiles p ON p.user_id = u.id
        INNER JOIN progress_restrictions pr ON pr.profile_id = p.id AND pr.restriction = $3
        LEFT JOIN images img ON img.user_id = u.id
      )
      SELECT rank, user_id, username, display_name, avatar_key, score
      FROM ranked
      WHERE rank BETWEEN $1 AND $2
      ORDER BY rank ASC
    `;
    params = [minRank, maxRank, restriction];
  } else {
    return [];
  }

  const result = await query<LiveRow>(rankedSql, params);
  return result.rows.map(liveRowToEntry);
}

// ─── Contexto competitivo del jugador (/me/summary) ──────────────────────────

/**
 * Fila interna que incluye datos del jugador y del siguiente rival en el snapshot.
 * Ordenamiento estable: score DESC, computed_at ASC, user_id ASC
 * (en empate de score, gana quien llegó antes y tiene user_id menor lexicográficamente).
 */
type RankingContextRow = {
  // datos del jugador actual
  current_rank: number;
  current_username: string;
  current_display_name: string | null;
  current_score: string;
  // datos del jugador de arriba (null si el jugador es primero)
  next_rank: number | null;
  next_username: string | null;
  next_display_name: string | null;
  next_score: string | null;
  is_from_snapshot: boolean;
};

/**
 * Obtiene el contexto competitivo del jugador en un scope.
 * Busca el jugador en el snapshot y al jugador que está exactamente un puesto
 * por encima (el inmediato siguiente a superar).
 *
 * Si no hay snapshot, hace fallback a consulta en vivo (más costosa).
 * Retorna null si el jugador no tiene progreso registrado en absoluto.
 */
export async function getUserRankingContext(
  userId: string,
  scope: LeaderboardScope = 'global_xp',
  generation: number | null = null
): Promise<{
  current: { rank: number; username: string; displayName: string | null; score: number };
  next: { rank: number; username: string; displayName: string | null; score: number } | null;
  isFromSnapshot: boolean;
} | null> {
  // Si se pasa una generación pinneada (misma que usará getNearbyEntries),
  // se filtra directo por ella en vez de resolver "current_generation" de nuevo:
  // evita que un refresh en background la cambie entre ambas consultas.
  const genFilterSql = generation !== null ? 'FROM leaderboard_snapshots s' : SNAPSHOT_CURRENT_GEN_SQL;
  const genWhereSql = generation !== null ? 'AND s.generation = $3' : '';
  const params = generation !== null ? [userId, scope, generation] : [userId, scope];

  // Intentar desde snapshot primero (rápido, no bloquea DB)
  const snapshotResult = await query<RankingContextRow>(
    `
      WITH player AS (
        SELECT s.rank, s.username, s.display_name, s.score
        ${genFilterSql}
        WHERE s.scope = $2 AND s.user_id = $1 AND s.score > 0 ${genWhereSql}
        LIMIT 1
      ),
      rival AS (
        SELECT s.rank, s.username, s.display_name, s.score
        ${genFilterSql}
        WHERE s.scope = $2
          AND s.rank = (SELECT rank FROM player) - 1
          ${genWhereSql}
        LIMIT 1
      )
      SELECT
        p.rank          AS current_rank,
        p.username      AS current_username,
        p.display_name  AS current_display_name,
        p.score         AS current_score,
        r.rank          AS next_rank,
        r.username      AS next_username,
        r.display_name  AS next_display_name,
        r.score         AS next_score,
        true            AS is_from_snapshot
      FROM player p
      LEFT JOIN rival r ON true
    `,
    params
  );

  if (snapshotResult.rows.length > 0) {
    const row = snapshotResult.rows[0];
    return {
      current: {
        rank:        row.current_rank,
        username:    row.current_username,
        displayName: row.current_display_name,
        score:       parseInt(String(row.current_score), 10)
      },
      next: row.next_rank !== null ? {
        rank:        row.next_rank,
        username:    row.next_username ?? '',
        displayName: row.next_display_name ?? null,
        score:       parseInt(String(row.next_score ?? '0'), 10)
      } : null,
      isFromSnapshot: true
    };
  }

  const liveResult = await queryLiveRankingContext(userId, scope);
  if (!liveResult) return null;
  return liveResult;
}

async function queryLiveRankingContext(
  userId: string,
  scope: LeaderboardScope
): Promise<{
  current: { rank: number; username: string; displayName: string | null; score: number };
  next: { rank: number; username: string; displayName: string | null; score: number } | null;
  isFromSnapshot: boolean;
} | null> {
  let rankedSql: string;
  let params: unknown[] = [userId];

  if (scope === 'global_xp') {
    rankedSql = `
      WITH ranked AS (
        SELECT
          u.id          AS user_id,
          u.username    AS username,
          u.name        AS display_name,
          COALESCE(p.exp_count, 0) AS score,
          RANK() OVER (
            ORDER BY COALESCE(p.exp_count, 0) DESC, u.id ASC
          )::integer AS rank
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
      ),
      player AS (
        SELECT * FROM ranked WHERE user_id = $1 LIMIT 1
      ),
      rival AS (
        SELECT * FROM ranked WHERE rank = (SELECT rank FROM player) - 1 LIMIT 1
      )
      SELECT
        pl.rank          AS current_rank,
        pl.username      AS current_username,
        pl.display_name  AS current_display_name,
        pl.score         AS current_score,
        rv.rank          AS next_rank,
        rv.username      AS next_username,
        rv.display_name  AS next_display_name,
        rv.score         AS next_score
      FROM player pl
      LEFT JOIN rival rv ON true
    `;
  } else if (scope === 'streak') {
    rankedSql = `
      WITH ranked AS (
        SELECT
          u.id          AS user_id,
          u.username    AS username,
          u.name        AS display_name,
          COALESCE(s.best_count, 0) AS score,
          RANK() OVER (
            ORDER BY COALESCE(s.best_count, 0) DESC, u.id ASC
          )::integer AS rank
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
        LEFT JOIN streaks  s ON s.id = p.streak_id
      ),
      player AS (
        SELECT * FROM ranked WHERE user_id = $1 LIMIT 1
      ),
      rival AS (
        SELECT * FROM ranked WHERE rank = (SELECT rank FROM player) - 1 LIMIT 1
      )
      SELECT
        pl.rank          AS current_rank,
        pl.username      AS current_username,
        pl.display_name  AS current_display_name,
        pl.score         AS current_score,
        rv.rank          AS next_rank,
        rv.username      AS next_username,
        rv.display_name  AS next_display_name,
        rv.score         AS next_score
      FROM player pl
      LEFT JOIN rival rv ON true
    `;
  } else if (scope.startsWith('restriction:')) {
    const restriction = scope.slice('restriction:'.length);
    rankedSql = `
      WITH ranked AS (
        SELECT
          u.id          AS user_id,
          u.username    AS username,
          u.name        AS display_name,
          COALESCE(pr.total_exp, 0) AS score,
          RANK() OVER (
            ORDER BY COALESCE(pr.total_exp, 0) DESC, u.id ASC
          )::integer AS rank
        FROM users u
        INNER JOIN profiles p ON p.user_id = u.id
        INNER JOIN progress_restrictions pr ON pr.profile_id = p.id AND pr.restriction = $2
      ),
      player AS (
        SELECT * FROM ranked WHERE user_id = $1 LIMIT 1
      ),
      rival AS (
        SELECT * FROM ranked WHERE rank = (SELECT rank FROM player) - 1 LIMIT 1
      )
      SELECT
        pl.rank          AS current_rank,
        pl.username      AS current_username,
        pl.display_name  AS current_display_name,
        pl.score         AS current_score,
        rv.rank          AS next_rank,
        rv.username      AS next_username,
        rv.display_name  AS next_display_name,
        rv.score         AS next_score
      FROM player pl
      LEFT JOIN rival rv ON true
    `;
    params = [userId, restriction];
  } else {
    return null;
  }

  const liveResult = await query<{
    current_rank: number;
    current_username: string;
    current_display_name: string | null;
    current_score: string;
    next_rank: number | null;
    next_username: string | null;
    next_display_name: string | null;
    next_score: string | null;
  }>(rankedSql, params);

  if (liveResult.rows.length === 0) return null;

  const row = liveResult.rows[0];
  return {
    current: {
      rank:        row.current_rank,
      username:    row.current_username,
      displayName: row.current_display_name,
      score:       parseInt(String(row.current_score), 10)
    },
    next: row.next_rank !== null ? {
      rank:        row.next_rank,
      username:    row.next_username ?? '',
      displayName: row.next_display_name ?? null,
      score:       parseInt(String(row.next_score ?? '0'), 10)
    } : null,
    isFromSnapshot: false
  };
}

