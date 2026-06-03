import { PoolClient } from 'pg';
import {
  CompletedNodeRow,
  InsertCompletedNodeInput,
  ProgresoRestriccionRow,
  UnlockedContentRow
} from './progreso-restriccion.types';

export async function upsertProgress(
  client: PoolClient,
  userId: string,
  profileId: string,
  restriction: string,
  expToAdd: number,
  completedGameIncrement: number
): Promise<ProgresoRestriccionRow> {
  const result = await client.query<ProgresoRestriccionRow>(
    `
      INSERT INTO player_progress (
        user_id,
        profile_id,
        restriction_type,
        total_exp,
        completed_games_count
      )
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (profile_id, restriction_type)
      DO UPDATE SET
        total_exp = player_progress.total_exp + EXCLUDED.total_exp,
        completed_games_count = player_progress.completed_games_count + EXCLUDED.completed_games_count,
        updated_at = now()
      RETURNING
        id,
        user_id,
        profile_id,
        restriction_type,
        total_exp,
        completed_nodes_count,
        completed_games_count,
        created_at,
        updated_at;
    `,
    [userId, profileId, restriction, expToAdd, completedGameIncrement]
  );

  return result.rows[0];
}

export async function incrementProgressCompletedNodes(
  client: PoolClient,
  progressId: string
): Promise<void> {
  await client.query(
    `
      UPDATE player_progress
      SET completed_nodes_count = completed_nodes_count + 1,
          updated_at = now()
      WHERE id = $1;
    `,
    [progressId]
  );
}

export async function upsertCompletedNode(
  client: PoolClient,
  input: InsertCompletedNodeInput
): Promise<{ node: CompletedNodeRow; wasNew: boolean }> {
  const existing = await client.query<{ id: string }>(
    `SELECT id FROM completed_nodes WHERE progress_id = $1 AND node_id = $2;`,
    [input.progressId, input.nodeId]
  );
  const wasNew = existing.rows.length === 0;

  const result = await client.query<CompletedNodeRow>(
    `
      INSERT INTO completed_nodes (
        user_id,
        progress_id,
        node_id,
        node_type,
        best_score,
        best_accuracy
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (progress_id, node_id)
      DO UPDATE SET
        best_score    = GREATEST(completed_nodes.best_score, EXCLUDED.best_score),
        best_accuracy = GREATEST(completed_nodes.best_accuracy, EXCLUDED.best_accuracy)
      RETURNING
        id,
        user_id,
        progress_id,
        node_id,
        node_type,
        completed_at,
        best_score,
        best_accuracy;
    `,
    [input.userId, input.progressId, input.nodeId, input.nodeType, input.score, input.accuracy]
  );

  return { node: result.rows[0], wasNew };
}

export async function listProgressByUserId(
  client: PoolClient,
  userId: string
): Promise<ProgresoRestriccionRow[]> {
  const result = await client.query<ProgresoRestriccionRow>(
    `
      SELECT
        id,
        user_id,
        profile_id,
        restriction_type,
        total_exp,
        completed_nodes_count,
        completed_games_count,
        created_at,
        updated_at
      FROM player_progress
      WHERE user_id = $1
      ORDER BY restriction_type;
    `,
    [userId]
  );

  return result.rows;
}

export async function listCompletedNodesByUserId(
  client: PoolClient,
  userId: string
): Promise<CompletedNodeRow[]> {
  const result = await client.query<CompletedNodeRow>(
    `
      SELECT
        id,
        user_id,
        progress_id,
        node_id,
        node_type,
        completed_at,
        best_score,
        best_accuracy
      FROM completed_nodes
      WHERE user_id = $1
      ORDER BY completed_at DESC;
    `,
    [userId]
  );

  return result.rows;
}

export async function listUnlockedContentByUserId(
  client: PoolClient,
  userId: string
): Promise<UnlockedContentRow[]> {
  const result = await client.query<UnlockedContentRow>(
    `
      SELECT id, user_id, progress_id, content_id, content_type, unlocked_at, source
      FROM unlocked_content
      WHERE user_id = $1
      ORDER BY unlocked_at DESC;
    `,
    [userId]
  );

  return result.rows;
}
