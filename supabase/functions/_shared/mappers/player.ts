import { formatBirthDate } from '../validators.ts';
import {
  CompletedNodeRow,
  GameRow,
  ProfileRow,
  ProgresoRestriccionRow,
  StreakRow,
  UserPublicRow,
} from '../types/player.ts';
import { toDateOnly } from '../repositories/streak.ts';

export interface PublicUser {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  birth_date: string | null;
  email_notifications_enabled: boolean;
  mail_verified_at: string | null;
}

export interface PublicProfile {
  id: string;
  exp_count: number;
  current_restriction: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface PublicStreak {
  id: string;
  current_count: number;
  best_count: number;
  last_activity_day: string | null;
  last_activity_at: string | null;
  updated_at: Date;
}

export interface PublicGame {
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

export interface PublicProgresoRestriccion {
  id: string;
  restriction_type: string;
  total_exp: number;
  completed_nodes_count: number;
  completed_games_count: number;
  map_completed: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface PublicCompletedNode {
  id: string;
  node_id: string;
  node_type: string | null;
  completed_at: Date;
  best_score: number | null;
  best_accuracy: string | null;
  last_accuracy: string | null;
}

export function toPublicUser(row: UserPublicRow): PublicUser {
  return {
    id: row.id,
    username: row.username,
    name: row.name,
    mail: row.mail,
    birth_date: formatBirthDate(row.birth_date),
    email_notifications_enabled: row.email_notifications_enabled,
    mail_verified_at: row.mail_verified_at ? row.mail_verified_at.toISOString() : null,
  };
}

export function toPublicProfile(row: ProfileRow): PublicProfile {
  return {
    id: row.id,
    exp_count: row.exp_count,
    current_restriction: row.current_restriction,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

export function toPublicStreak(row: StreakRow): PublicStreak {
  return {
    id: row.id,
    current_count: row.current_count,
    best_count: row.best_count,
    last_activity_day: toDateOnly(row.last_activity_day),
    last_activity_at:
      row.last_activity_at instanceof Date && !Number.isNaN(row.last_activity_at.getTime())
        ? row.last_activity_at.toISOString()
        : null,
    updated_at: row.updated_at,
  };
}

export function toPublicGame(row: GameRow): PublicGame {
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
    clientRunId: row.client_run_id,
  };
}

export function toPublicProgresoRestriccion(row: ProgresoRestriccionRow): PublicProgresoRestriccion {
  return {
    id: row.id,
    restriction_type: row.restriction_type,
    total_exp: row.total_exp,
    completed_nodes_count: row.completed_nodes_count,
    completed_games_count: row.completed_games_count,
    map_completed: row.map_completed,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

export function toPublicCompletedNode(row: CompletedNodeRow): PublicCompletedNode {
  return {
    id: row.id,
    node_id: row.node_id,
    node_type: row.node_type,
    completed_at: row.completed_at,
    best_score: row.best_score,
    best_accuracy: row.best_accuracy,
    last_accuracy: row.last_accuracy,
  };
}

export interface ProgresoRestriccionResponse {
  user: UserPublicRow;
  profile: PublicProfile;
  streak: PublicStreak;
  progress: PublicProgresoRestriccion[];
  completedNodes: PublicCompletedNode[];
  recentGames: PublicGame[];
}

export interface SaveProgresoRestriccionResponse {
  user: UserPublicRow;
  profile: PublicProfile;
  streak: PublicStreak;
  progress: PublicProgresoRestriccion;
  game: PublicGame;
  completedNode: PublicCompletedNode | null;
  mapCompleted: boolean;
  summary: ProgresoRestriccionResponse | null;
}
