import { PoolClient } from 'pg';
import * as historyGameRepository from '../history-game/history-game.repository';
import {
  CompletedNodeRow,
  InsertCompletedNodeInput,
  ProgresoRestriccionRow
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
      INSERT INTO progress_restrictions (
        user_id,
        profile_id,
        restriction,
        total_exp,
        completed_games_count
      )
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (profile_id, restriction)
      DO UPDATE SET
        total_exp = progress_restrictions.total_exp + EXCLUDED.total_exp,
        completed_games_count = progress_restrictions.completed_games_count + EXCLUDED.completed_games_count,
        updated_at = now()
      RETURNING
        id,
        user_id,
        profile_id,
        restriction AS restriction_type,
        total_exp,
        completed_nodes_count,
        completed_games_count,
        map_completed,
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
): Promise<{ map_completed: boolean }> {
  const result = await client.query<{ map_completed: boolean }>(
    `
      UPDATE progress_restrictions pr
      SET
        completed_nodes_count = pr.completed_nodes_count + 1,
        map_completed = CASE
          WHEN (pr.completed_nodes_count + 1) >= COALESCE(
            (SELECT total_nodes FROM restriction_node_config WHERE restriction = pr.restriction),
            2147483647
          ) THEN true
          ELSE pr.map_completed
        END,
        updated_at = now()
      WHERE pr.id = $1
      RETURNING pr.map_completed;
    `,
    [progressId]
  );
  return result.rows[0];
}

export async function getCompletedNodeByProgressAndNode(
  client: PoolClient,
  progressId: string,
  nodeId: string
): Promise<CompletedNodeRow | null> {
  const result = await client.query<CompletedNodeRow>(
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
      WHERE progress_id = $1 AND node_id = $2 AND completed = true;
    `,
    [progressId, nodeId]
  );

  return result.rows[0] ?? null;
}

export async function upsertCompletedNode(
  client: PoolClient,
  input: InsertCompletedNodeInput
): Promise<{ node: CompletedNodeRow; wasNew: boolean }> {
  const history = await historyGameRepository.ensureNodeHistory(client, {
    userId: input.userId,
    progressId: input.progressId,
    nodeId: input.nodeId,
    nodeType: input.nodeType,
    completed: true,
    score: input.score,
    accuracy: input.accuracy
  });

  const result = await client.query<CompletedNodeRow>(
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
      WHERE id = $1;
    `,
    [history.historyId]
  );

  return { node: result.rows[0], wasNew: history.wasNewlyCompleted };
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
        restriction AS restriction_type,
        total_exp,
        completed_nodes_count,
        completed_games_count,
        map_completed,
        created_at,
        updated_at
      FROM progress_restrictions
      WHERE user_id = $1
      ORDER BY restriction;
    `,
    [userId]
  );

  return result.rows;
}

export async function listCompletedNodesByUserId(
  client: PoolClient,
  userId: string
): Promise<CompletedNodeRow[]> {
  return historyGameRepository.listCompletedNodesByUserId(client, userId);
}
