import { ProfileRow } from './profile.types';

export interface PublicProfile {
  id: string;
  exp_count: number;
  current_restriction: string | null;
  created_at: Date;
  updated_at: Date;
}

export function toPublicProfile(row: ProfileRow): PublicProfile {
  return {
    id: row.id,
    exp_count: row.exp_count,
    current_restriction: row.current_restriction,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}
