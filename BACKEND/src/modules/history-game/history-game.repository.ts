import { PoolClient } from 'pg';
import { HistoryGameRow } from './history-game.types';

export interface EnsureNodeHistoryInput {
  userId: string;
  progressId: string;
  nodeId: string;
  nodeType: string | null;
  completed: boolean;
  score: number;
  accuracy: number | null;
}

export interface EnsureNodeHistoryResult {
  historyId: string;
  wasNew: boolean;
  wasNewlyCompleted: boolean;
}

export async function ensureNodeHistory(
  client: PoolClient,
  input: EnsureNodeHistoryInput
): Promise<EnsureNodeHistoryResult> {
  // CTE con FOR UPDATE: serializa accesos concurrentes al mismo nodo y derivar
  // wasNewlyCompleted de forma atómica sin race condition.
  const result = await client.query<{
    id: string;
    was_inserted: boolean;
    was_already_completed: boolean;
  }>(
    `
      WITH locked AS (
        SELECT id, completed AS was_completed
        FROM history_games
        WHERE progress_id = $2 AND node_id = $3
        FOR UPDATE
      ),
      upserted AS (
        INSERT INTO history_games (
          user_id, progress_id, node_id, node_type,
          completed, best_score, best_accuracy, completed_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, CASE WHEN $5 THEN now() ELSE NULL END)
        ON CONFLICT (progress_id, node_id)
        DO UPDATE SET
          node_type     = COALESCE(EXCLUDED.node_type, history_games.node_type),
          completed     = history_games.completed OR EXCLUDED.completed,
          best_score    = GREATEST(COALESCE(history_games.best_score, 0), COALESCE(EXCLUDED.best_score, 0)),
          best_accuracy = GREATEST(
            COALESCE(history_games.best_accuracy, 0),
            COALESCE(EXCLUDED.best_accuracy, 0)
          ),
          completed_at  = COALESCE(history_games.completed_at, EXCLUDED.completed_at)
        RETURNING id, (xmax::text::bigint = 0) AS was_inserted
      )
      SELECT
        u.id,
        u.was_inserted,
        COALESCE(l.was_completed, false) AS was_already_completed
      FROM upserted u
      LEFT JOIN locked l ON true;
    `,
    [
      input.userId,
      input.progressId,
      input.nodeId,
      input.nodeType,
      input.completed,
      input.score,
      input.accuracy
    ]
  );

  const row = result.rows[0];
  const wasNew = row.was_inserted;
  const wasAlreadyCompleted = row.was_already_completed;
  const wasNewlyCompleted = input.completed && !wasAlreadyCompleted;

  return { historyId: row.id, wasNew, wasNewlyCompleted };
}

export async function listHistoryGamesByUserId(
  client: PoolClient,
  userId: string,
  limit = 20
): Promise<HistoryGameRow[]> {
  const result = await client.query<HistoryGameRow>(
    `
      SELECT
        g.id,
        g.user_id,
        g.progress_id,
        g.game_type,
        g.node_id,
        g.accuracy,
        g.score,
        g.completed,
        g.started_at,
        g.completed_at,
        g.created_at,
        g.correct_answers,
        g.wrong_answers,
        g.duration_seconds,
        g.finished_at,
        g.client_run_id
      FROM games g
      WHERE g.user_id = $1
      ORDER BY g.created_at DESC
      LIMIT $2;
    `,
    [userId, limit]
  );

  return result.rows;
}

export async function listCompletedNodesByUserId(
  client: PoolClient,
  userId: string
): Promise<
  Array<{
    id: string;
    user_id: string;
    progress_id: string;
    node_id: string;
    node_type: string | null;
    completed_at: Date;
    best_score: number | null;
    best_accuracy: string | null;
  }>
> {
  const result = await client.query(
    `
      SELECT
        id,
        user_id,
        progress_id,
        node_id,
        node_type,
        COALESCE(completed_at, created_at) AS completed_at,
        best_score,
        best_accuracy
      FROM history_games
      WHERE user_id = $1
        AND node_id IS NOT NULL
        AND completed = true
      ORDER BY completed_at DESC NULLS LAST;
    `,
    [userId]
  );

  return result.rows;
}
