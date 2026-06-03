/**
 * GAME del MER.
 *
 * Responsabilidad:
 * - Guardar el resumen puntual de una partida.
 * - Preservar métricas como accuracy, score, aciertos y errores.
 * - Evitar duplicados usando clientRunId.
 */
import { PoolClient } from 'pg';
import { GameRow, InsertGameInput } from './game.types';

export async function insertGame(
  client: PoolClient,
  input: InsertGameInput
): Promise<GameRow> {
  const result = await client.query<GameRow>(
    `
      INSERT INTO game_sessions (
        user_id,
        progress_id,
        game_type,
        node_id,
        accuracy,
        completed,
        score,
        completed_at,
        correct_answers,
        wrong_answers,
        duration_seconds,
        finished_at,
        client_run_id
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, CASE WHEN $6 THEN now() ELSE NULL END,
              $8, $9, $10, $11, $12)
      RETURNING
        id,
        user_id,
        progress_id,
        game_type,
        node_id,
        accuracy,
        score,
        completed,
        started_at,
        completed_at,
        created_at,
        correct_answers,
        wrong_answers,
        duration_seconds,
        finished_at,
        client_run_id;
    `,
    [
      input.userId,
      input.progressId,
      input.gameType,
      input.nodeId,
      input.accuracy,
      input.completed,
      input.score,
      input.correctAnswers ?? null,
      input.wrongAnswers ?? null,
      input.durationSeconds ?? null,
      input.finishedAt ?? null,
      input.clientRunId ?? null
    ]
  );

  return result.rows[0];
}

export async function findGameByClientRunId(
  client: PoolClient,
  progressId: string,
  clientRunId: string
): Promise<GameRow | null> {
  const result = await client.query<GameRow>(
    `
      SELECT
        id,
        user_id,
        progress_id,
        game_type,
        node_id,
        accuracy,
        score,
        completed,
        started_at,
        completed_at,
        created_at,
        correct_answers,
        wrong_answers,
        duration_seconds,
        finished_at,
        client_run_id
      FROM game_sessions
      WHERE progress_id = $1 AND client_run_id = $2
      LIMIT 1;
    `,
    [progressId, clientRunId]
  );

  return result.rows[0] ?? null;
}

export async function listRecentGamesByUserId(
  client: PoolClient,
  userId: string,
  limit = 20
): Promise<GameRow[]> {
  const result = await client.query<GameRow>(
    `
      SELECT
        id,
        user_id,
        progress_id,
        game_type,
        node_id,
        accuracy,
        score,
        completed,
        started_at,
        completed_at,
        created_at,
        correct_answers,
        wrong_answers,
        duration_seconds,
        finished_at,
        client_run_id
      FROM game_sessions
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT $2;
    `,
    [userId, limit]
  );

  return result.rows;
}
