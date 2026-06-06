import {
  CompletedNodeRow,
  ProgresoRestriccionRow
} from './progreso-restriccion.types';
import { UserPublicRow } from '../user/user.types';
import { PublicProfile } from '../profile/profile.mapper';
import { PublicStreak } from '../streak/streak.mapper';
import { PublicGame } from '../game/game.mapper';

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
    updated_at: row.updated_at
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
  /** true solo cuando este POST completó el último nodo del mapa (primera vez) */
  mapCompleted: boolean;
  summary: ProgresoRestriccionResponse;
}
