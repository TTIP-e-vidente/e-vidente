-- La racha se recalcula desde los días con partidas completadas del usuario
-- (streak.repository.ts registerStreakActivity). Este índice evita el scan
-- completo de games en cada sync.
CREATE INDEX IF NOT EXISTS games_user_completed_finished_idx
  ON games (user_id, completed, finished_at DESC);
