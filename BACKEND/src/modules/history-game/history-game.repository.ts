import { PoolClient } from 'pg';
import { HistoryGameRow } from './history-game.types';

export async function listHistoryGamesByUserId(
  client: PoolClient,
  userId: string,
  limit = 20
): Promise<HistoryGameRow[]> {
  const result = await client.query<HistoryGameRow>(
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
