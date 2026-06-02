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
  profile_id: string;
  current_count: number;
  best_count: number;
  last_activity_day: Date | null;
  updated_at: Date;
}

export interface PlayerProgressRow {
  id: string;
  user_id: string;
  profile_id: string;
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
  correct_answers: number | null;
  wrong_answers: number | null;
  duration_seconds: number | null;
  finished_at: Date | null;
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
  progress_id: string | null;
  content_id: string;
  content_type: string;
  unlocked_at: Date;
  source: string | null;
}

export interface InsertGameSessionInput {
  userId: string;
  progressId: string;
  gameType: string;
  nodeId: string | null;
  accuracy: number | null;
  completed: boolean;
  score: number;
  correctAnswers?: number | null;
  wrongAnswers?: number | null;
  durationSeconds?: number | null;
  finishedAt?: string | null;
}

export interface InsertCompletedNodeInput {
  userId: string;
  progressId: string;
  nodeId: string;
  nodeType: string | null;
  score: number;
  accuracy: number | null;
}

export interface SaveAuthenticatedProgressInput {
  userId: string;
  restriction?: unknown;
  expToAdd?: unknown;
  nodeId?: unknown;
  gameType?: unknown;
  accuracy?: unknown;
  completed?: unknown;
  score?: unknown;
  correctAnswers?: unknown;
  wrongAnswers?: unknown;
  durationSeconds?: unknown;
  finishedAt?: unknown;
}

export interface SaveDevProgressInput {
  username: string;
  name?: string;
  restriction: string;
  expToAdd: number;
  nodeId?: string;
  gameType?: string;
  accuracy?: number;
  completed?: boolean;
  score?: number;
  correctAnswers?: number;
  wrongAnswers?: number;
  durationSeconds?: number;
  finishedAt?: string;
}

export type SavePlayerProgressInput = SaveDevProgressInput;
