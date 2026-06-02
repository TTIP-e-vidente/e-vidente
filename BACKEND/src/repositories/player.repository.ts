import { PoolClient } from 'pg';
import { query } from '../config/database';

export interface UserPublicRow {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  age: number | null;
}

export interface PlayerProfileRow {
  id: string;
  user_id: string;
  exp_count: number;
  current_restriction: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface PlayerStreakRow {
  id: string;
  user_id: string;
  current_count: number;
  best_count: number;
  last_activity_day: Date | null;
  updated_at: Date;
}

export interface PlayerProgressRow {
  id: string;
  user_id: string;
  restriction_type: string;
  total_exp: number;
  completed_nodes_count: number;
  completed_games_count: number;
  created_at: Date;
  updated_at: Date;
}

export interface GameSessionRow {
  id: string;
  user_id: string;
  progress_id: string | null;
  game_type: string;
  node_id: string | null;
  accuracy: string | null;
  score: number;
  completed: boolean;
  started_at: Date;
  completed_at: Date | null;
  created_at: Date;
}

export interface CompletedNodeRow {
  id: string;
  user_id: string;
  progress_id: string | null;
  node_id: string;
  node_type: string | null;
  completed_at: Date;
  best_score: number | null;
  best_accuracy: string | null;
}

export interface UnlockedContentRow {
  id: string;
  user_id: string;
  content_id: string;
  content_type: string;
  unlocked_at: Date;
  source: string | null;
}

export async function findPublicUserById(userId: string): Promise<UserPublicRow | null> {
  const result = await query<UserPublicRow>(
    `
      SELECT id, username, name, COALESCE(mail, email) AS mail, age
      FROM users
      WHERE id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function findPublicUserByUsername(
  client: PoolClient,
  username: string
): Promise<UserPublicRow | null> {
  const result = await client.query<UserPublicRow>(
    `
      SELECT id, username, name, COALESCE(mail, email) AS mail, age
      FROM users
      WHERE username = $1;
    `,
    [username]
  );

  return result.rows[0] ?? null;
}

export async function upsertDevUser(
  client: PoolClient,
  username: string,
  name: string
): Promise<UserPublicRow> {
  const result = await client.query<UserPublicRow>(
    `
      INSERT INTO users (username, name, display_name)
      VALUES ($1, $2, $2)
      ON CONFLICT (username)
      DO UPDATE SET
        name = COALESCE(EXCLUDED.name, users.name),
        display_name = COALESCE(EXCLUDED.name, users.display_name),
        updated_at = now()
      RETURNING id, username, name, COALESCE(mail, email) AS mail, age;
    `,
    [username, name]
  );

  return result.rows[0];
}

export async function ensureProfile(
  client: PoolClient,
  userId: string,
  restriction: string | null = null
): Promise<PlayerProfileRow> {
  const result = await client.query<PlayerProfileRow>(
    `
      INSERT INTO player_profiles (user_id, current_restriction)
      VALUES ($1, $2)
      ON CONFLICT (user_id)
      DO UPDATE SET
        current_restriction = COALESCE(EXCLUDED.current_restriction, player_profiles.current_restriction),
        updated_at = now()
      RETURNING id, user_id, exp_count, current_restriction, created_at, updated_at;
    `,
    [userId, restriction]
  );

  return result.rows[0];
}

export async function addProfileExp(
  client: PoolClient,
  userId: string,
  expToAdd: number,
  restriction: string
): Promise<PlayerProfileRow> {
  const result = await client.query<PlayerProfileRow>(
    `
      INSERT INTO player_profiles (user_id, exp_count, current_restriction)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id)
      DO UPDATE SET
        exp_count = player_profiles.exp_count + EXCLUDED.exp_count,
        current_restriction = EXCLUDED.current_restriction,
        updated_at = now()
      RETURNING id, user_id, exp_count, current_restriction, created_at, updated_at;
    `,
    [userId, expToAdd, restriction]
  );

  return result.rows[0];
}

export async function ensureStreak(client: PoolClient, userId: string): Promise<PlayerStreakRow> {
  const result = await client.query<PlayerStreakRow>(
    `
      INSERT INTO player_streaks (user_id, current_count, best_count, last_activity_day)
      VALUES ($1, 1, 1, CURRENT_DATE)
      ON CONFLICT (user_id)
      DO UPDATE SET
        current_count = GREATEST(player_streaks.current_count, 1),
        best_count = GREATEST(player_streaks.best_count, player_streaks.current_count, 1),
        last_activity_day = COALESCE(player_streaks.last_activity_day, CURRENT_DATE),
        updated_at = now()
      RETURNING id, user_id, current_count, best_count, last_activity_day, updated_at;
    `,
    [userId]
  );

  return result.rows[0];
}

export async function upsertProgress(
  client: PoolClient,
  userId: string,
  restriction: string,
  expToAdd: number,
  completedGameIncrement: number
): Promise<PlayerProgressRow> {
  const result = await client.query<PlayerProgressRow>(
    `
      INSERT INTO player_progress (
        user_id,
        restriction_type,
        total_exp,
        completed_games_count
      )
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (user_id, restriction_type)
      DO UPDATE SET
        total_exp = player_progress.total_exp + EXCLUDED.total_exp,
        completed_games_count = player_progress.completed_games_count + EXCLUDED.completed_games_count,
        updated_at = now()
      RETURNING
        id,
        user_id,
        restriction_type,
        total_exp,
        completed_nodes_count,
        completed_games_count,
        created_at,
        updated_at;
    `,
    [userId, restriction, expToAdd, completedGameIncrement]
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

export async function insertGameSession(
  client: PoolClient,
  input: {
    userId: string;
    progressId: string;
    gameType: string;
    nodeId: string | null;
    accuracy: number | null;
    completed: boolean;
    score: number;
  }
): Promise<GameSessionRow> {
  const result = await client.query<GameSessionRow>(
    `
      INSERT INTO game_sessions (
        user_id,
        progress_id,
        game_type,
        node_id,
        accuracy,
        completed,
        score,
        completed_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, CASE WHEN $6 THEN now() ELSE NULL END)
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
        created_at;
    `,
    [
      input.userId,
      input.progressId,
      input.gameType,
      input.nodeId,
      input.accuracy,
      input.completed,
      input.score
    ]
  );

  return result.rows[0];
}

export async function insertCompletedNodeIfMissing(
  client: PoolClient,
  input: {
    userId: string;
    progressId: string;
    nodeId: string;
    nodeType: string | null;
    score: number;
    accuracy: number | null;
  }
): Promise<CompletedNodeRow | null> {
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
      ON CONFLICT (user_id, node_id)
      DO NOTHING
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

  return result.rows[0] ?? null;
}

export async function getProfileByUserId(
  client: PoolClient,
  userId: string
): Promise<PlayerProfileRow | null> {
  const result = await client.query<PlayerProfileRow>(
    `
      SELECT id, user_id, exp_count, current_restriction, created_at, updated_at
      FROM player_profiles
      WHERE user_id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function getStreakByUserId(
  client: PoolClient,
  userId: string
): Promise<PlayerStreakRow | null> {
  const result = await client.query<PlayerStreakRow>(
    `
      SELECT id, user_id, current_count, best_count, last_activity_day, updated_at
      FROM player_streaks
      WHERE user_id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function listProgressByUserId(
  client: PoolClient,
  userId: string
): Promise<PlayerProgressRow[]> {
  const result = await client.query<PlayerProgressRow>(
    `
      SELECT
        id,
        user_id,
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
      SELECT id, user_id, content_id, content_type, unlocked_at, source
      FROM unlocked_content
      WHERE user_id = $1
      ORDER BY unlocked_at DESC;
    `,
    [userId]
  );

  return result.rows;
}

export async function listRecentGameSessionsByUserId(
  client: PoolClient,
  userId: string,
  limit = 20
): Promise<GameSessionRow[]> {
  const result = await client.query<GameSessionRow>(
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
        created_at
      FROM game_sessions
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT $2;
    `,
    [userId, limit]
  );

  return result.rows;
}
