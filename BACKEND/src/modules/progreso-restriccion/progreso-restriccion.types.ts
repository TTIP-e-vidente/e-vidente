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
  localDay?: string;
  clientRunId?: string;
}

export type SaveProgresoRestriccionInput = SaveDevProgressInput;
