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
