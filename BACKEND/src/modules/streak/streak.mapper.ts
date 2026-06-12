import { toDateOnly } from './streak.repository';
import { StreakRow } from './streak.types';

export interface PublicStreak {
  id: string;
  current_count: number;
  best_count: number;
  /** Fecha YYYY-MM-DD; un Date se serializaría a ISO UTC y podría correrse de día. */
  last_activity_day: string | null;
  last_activity_at: string | null;
  updated_at: Date;
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
    updated_at: row.updated_at
  };
}
