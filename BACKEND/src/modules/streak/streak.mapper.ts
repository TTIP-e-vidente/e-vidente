import { StreakRow } from './streak.types';

export interface PublicStreak {
  id: string;
  current_count: number;
  best_count: number;
  last_activity_day: Date | null;
  updated_at: Date;
}

export function toPublicStreak(row: StreakRow): PublicStreak {
  return {
    id: row.id,
    current_count: row.current_count,
    best_count: row.best_count,
    last_activity_day: row.last_activity_day,
    updated_at: row.updated_at
  };
}
