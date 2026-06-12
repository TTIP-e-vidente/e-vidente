export interface StreakRow {
  id: string;
  user_id: string;
  profile_id: string;
  current_count: number;
  best_count: number;
  last_activity_day: Date | null;
  last_activity_at: Date | null;
  updated_at: Date;
}
