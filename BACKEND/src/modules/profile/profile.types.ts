export interface ProfileRow {
  id: string;
  user_id: string;
  exp_count: number;
  current_restriction: string | null;
  created_at: Date;
  updated_at: Date;
}
