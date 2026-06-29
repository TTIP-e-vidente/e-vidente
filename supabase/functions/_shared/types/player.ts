export interface UserPublicRow {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  birth_date: Date | string | null;
  email_notifications_enabled: boolean;
  mail_verified_at: Date | null;
}

export interface ProfileRow {
  id: string;
  user_id: string;
  streak_id: string | null;
  exp_count: number;
  current_restriction: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface StreakRow {
  id: string;
  user_id: string;
  profile_id: string;
  current_count: number;
  best_count: number;
  last_activity_day: Date | null;
  last_activity_at: Date | null;
  updated_at: Date;
}

export interface GameRow {
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
  client_run_id: string | null;
}

export interface InsertGameResult {
  game: GameRow;
  wasNewlyCompleted: boolean;
}

export interface InsertGameInput {
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
  localDay?: string | null;
  clientRunId?: string | null;
}

export interface ProgresoRestriccionRow {
  id: string;
  user_id: string;
  profile_id: string;
  restriction_type: string;
  total_exp: number;
  completed_nodes_count: number;
  completed_games_count: number;
  map_completed: boolean;
  created_at: Date;
  updated_at: Date;
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
  last_accuracy: string | null;
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
  localDay?: unknown;
  clientRunId?: unknown;
}

export interface HistoryGameRow {
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
  client_run_id: string | null;
}

export interface UpdateUserProfileInput {
  name?: string;
  mail?: string | null;
  birth_date?: string | null;
  email_notifications_enabled?: boolean;
}
