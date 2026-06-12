/**
 * GAME del MER: cada partida jugada, enlazada a history_games (nodo del mapa).
 */
import { PoolClient } from "pg";
import * as historyGameRepository from "../history-game/history-game.repository";
import { GameRow, InsertGameInput, InsertGameResult } from "./game.types";

export async function insertGame(
  client: PoolClient,
  input: InsertGameInput,
): Promise<InsertGameResult> {
  let historyId: string;
  let wasNewlyCompleted = false;

  if (input.nodeId) {
    const history = await historyGameRepository.ensureNodeHistory(client, {
      userId: input.userId,
      progressId: input.progressId,
      nodeId: input.nodeId,
      nodeType: input.gameType,
      completed: input.completed,
      score: input.score,
      accuracy: input.accuracy,
    });
    historyId = history.historyId;
    wasNewlyCompleted = history.wasNewlyCompleted;
  } else {
    const historyResult = await client.query<{ id: string }>(
      `
        INSERT INTO history_games (progress_id, completed, user_id)
        VALUES ($1, $2, $3)
        RETURNING id;
      `,
      [input.progressId, input.completed, input.userId],
    );
    historyId = historyResult.rows[0].id;
  }

  const result = await client.query<GameRow>(
    `
      INSERT INTO games (
        history_id,
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
        local_day,
        client_run_id
      )
      VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8,
        CASE WHEN $7 THEN now() ELSE NULL END,
        $9, $10, $11, $12, $13, $14
      )
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
      historyId,
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
      input.localDay ?? null,
      input.clientRunId ?? null,
    ],
  );

  return { game: result.rows[0], wasNewlyCompleted };
}

export async function findGameByClientRunId(
  client: PoolClient,
  progressId: string,
  clientRunId: string,
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
      FROM games
      WHERE progress_id = $1 AND client_run_id = $2
      LIMIT 1;
    `,
    [progressId, clientRunId],
  );

  return result.rows[0] ?? null;
}

export async function listRecentGamesByUserId(
  client: PoolClient,
  userId: string,
  limit = 20,
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
      FROM games
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT $2;
    `,
    [userId, limit],
  );

  return result.rows;
}
