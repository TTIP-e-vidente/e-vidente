import {
  CompletedNodeRow,
  GameSessionRow,
  PlayerProfileRow,
  PlayerProgressRow,
  PlayerStreakRow,
  UnlockedContentRow,
  UserPublicRow
} from './player.types';

export interface PublicPlayerProfile {
  id: string;
  exp_count: number;
  current_restriction: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface PublicPlayerStreak {
  id: string;
  current_count: number;
  best_count: number;
  last_activity_day: Date | null;
  updated_at: Date;
}

export interface PublicPlayerProgress {
  id: string;
  restriction_type: string;
  total_exp: number;
  completed_nodes_count: number;
  completed_games_count: number;
  created_at: Date;
  updated_at: Date;
}

export interface PublicGameSession {
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

export interface PublicCompletedNode {
  id: string;
  node_id: string;
  node_type: string | null;
  completed_at: Date;
  best_score: number | null;
  best_accuracy: string | null;
}

export interface PublicUnlockedContent {
  id: string;
  content_id: string;
  content_type: string;
  unlocked_at: Date;
  source: string | null;
}

export function toPublicPlayerProfile(row: PlayerProfileRow): PublicPlayerProfile {
  return {
    id: row.id,
    exp_count: row.exp_count,
    current_restriction: row.current_restriction,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

export function toPublicPlayerStreak(row: PlayerStreakRow): PublicPlayerStreak {
  return {
    id: row.id,
    current_count: row.current_count,
    best_count: row.best_count,
    last_activity_day: row.last_activity_day,
    updated_at: row.updated_at
  };
}

export function toPublicPlayerProgress(row: PlayerProgressRow): PublicPlayerProgress {
  return {
    id: row.id,
    restriction_type: row.restriction_type,
    total_exp: row.total_exp,
    completed_nodes_count: row.completed_nodes_count,
    completed_games_count: row.completed_games_count,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

export function toPublicGameSession(row: GameSessionRow): PublicGameSession {
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

export function toPublicCompletedNode(row: CompletedNodeRow): PublicCompletedNode {
  return {
    id: row.id,
    node_id: row.node_id,
    node_type: row.node_type,
    completed_at: row.completed_at,
    best_score: row.best_score,
    best_accuracy: row.best_accuracy
  };
}

export function toPublicUnlockedContent(row: UnlockedContentRow): PublicUnlockedContent {
  return {
    id: row.id,
    content_id: row.content_id,
    content_type: row.content_type,
    unlocked_at: row.unlocked_at,
    source: row.source
  };
}

// ── Response shapes ───────────────────────────────────────────────────────────

export interface PlayerMeResponse {
  user: UserPublicRow;
  profile: PublicPlayerProfile;
  streak: PublicPlayerStreak;
}

export interface PlayerProgressResponse {
  user: UserPublicRow;
  profile: PublicPlayerProfile;
  streak: PublicPlayerStreak;
  progress: PublicPlayerProgress[];
  completedNodes: PublicCompletedNode[];
  unlockedContent: PublicUnlockedContent[];
  recentGameSessions: PublicGameSession[];
}

export interface SavePlayerProgressResponse {
  user: UserPublicRow;
  profile: PublicPlayerProfile;
  streak: PublicPlayerStreak;
  progress: PublicPlayerProgress;
  gameSession: PublicGameSession;
  completedNode: PublicCompletedNode | null;
  summary: PlayerProgressResponse;
}
