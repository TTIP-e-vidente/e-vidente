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
