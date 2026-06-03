import { HistoryGameRow } from './history-game.types';

export interface PublicHistoryGame {
  id: string;
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
  clientRunId: string | null;
}

export function toPublicHistoryGame(row: HistoryGameRow): PublicHistoryGame {
  return {
    id: row.id,
    game_type: row.game_type,
    node_id: row.node_id,
    accuracy: row.accuracy,
    score: row.score,
    completed: row.completed,
    started_at: row.started_at,
    completed_at: row.completed_at,
    created_at: row.created_at,
    correct_answers: row.correct_answers,
    wrong_answers: row.wrong_answers,
    duration_seconds: row.duration_seconds,
    finished_at: row.finished_at,
    clientRunId: row.client_run_id
  };
}
