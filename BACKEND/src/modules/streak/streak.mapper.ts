import { toDateOnly } from './streak.repository';
import { StreakRow } from './streak.types';

export interface PublicStreak {
  id: string;
  current_count: number;
  best_count: number;
  /** Fecha YYYY-MM-DD; un Date se serializaría a ISO UTC y podría correrse de día. */
  last_activity_day: string | null;
  updated_at: Date;
}

export function toPublicStreak(row: StreakRow): PublicStreak {
  return {
    id: row.id,
    current_count: row.current_count,
    best_count: row.best_count,
    last_activity_day: toDateOnly(row.last_activity_day),
    updated_at: row.updated_at
  };
}
