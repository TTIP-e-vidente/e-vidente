-- Alinea el esquema al MER Excalidraw:
--   users → profiles → streaks
--   profiles → progress_restrictions → history_games → games
-- Migra datos desde player_* / game_sessions y elimina tablas legacy.

-- 1. Extender tablas del MER
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS streak_id UUID,
  ADD COLUMN IF NOT EXISTS current_restriction VARCHAR(30);

ALTER TABLE progress_restrictions
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS total_exp INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS completed_nodes_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS completed_games_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE history_games
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE games
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS progress_id UUID REFERENCES progress_restrictions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS correct_answers INTEGER NULL,
  ADD COLUMN IF NOT EXISTS wrong_answers INTEGER NULL,
  ADD COLUMN IF NOT EXISTS duration_seconds INTEGER NULL,
  ADD COLUMN IF NOT EXISTS finished_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS client_run_id VARCHAR(120) NULL,
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- 2. Migrar player_profiles → profiles
INSERT INTO profiles (user_id, exp_count, current_restriction, created_at, updated_at)
SELECT user_id, exp_count, current_restriction, created_at, updated_at
FROM player_profiles
ON CONFLICT (user_id) DO UPDATE SET
  exp_count = GREATEST(profiles.exp_count, EXCLUDED.exp_count),
  current_restriction = COALESCE(EXCLUDED.current_restriction, profiles.current_restriction),
  updated_at = now();

-- 3. Migrar player_streaks → streaks (streaks.profile_id existe hasta el paso 5)
INSERT INTO streaks (profile_id, current_count, best_count, last_activity_day, updated_at)
SELECT p.id, ps.current_count, ps.best_count, ps.last_activity_day, ps.updated_at
FROM player_streaks ps
JOIN profiles p ON p.user_id = ps.user_id
ON CONFLICT (profile_id) DO UPDATE SET
  current_count = GREATEST(streaks.current_count, EXCLUDED.current_count),
  best_count = GREATEST(streaks.best_count, EXCLUDED.best_count),
  last_activity_day = COALESCE(EXCLUDED.last_activity_day, streaks.last_activity_day),
  updated_at = now();

UPDATE profiles p
SET streak_id = s.id
FROM streaks s
WHERE s.profile_id = p.id
  AND p.streak_id IS NULL;

-- 4. Migrar player_progress → progress_restrictions (conserva IDs para completed_nodes)
INSERT INTO progress_restrictions (
  id,
  profile_id,
  user_id,
  restriction,
  total_exp,
  completed_nodes_count,
  completed_games_count,
  created_at,
  updated_at
)
SELECT
  pp.id,
  p.id,
  pp.user_id,
  pp.restriction_type,
  pp.total_exp,
  pp.completed_nodes_count,
  pp.completed_games_count,
  pp.created_at,
  pp.updated_at
FROM player_progress pp
JOIN profiles p ON p.user_id = pp.user_id
ON CONFLICT (profile_id, restriction) DO UPDATE SET
  total_exp = GREATEST(progress_restrictions.total_exp, EXCLUDED.total_exp),
  completed_nodes_count = GREATEST(
    progress_restrictions.completed_nodes_count,
    EXCLUDED.completed_nodes_count
  ),
  completed_games_count = GREATEST(
    progress_restrictions.completed_games_count,
    EXCLUDED.completed_games_count
  ),
  updated_at = now();

-- 5. Perfil apunta a racha (MER); streaks deja de depender de profile_id
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_streak_id_fkey;

ALTER TABLE profiles
  ADD CONSTRAINT profiles_streak_id_fkey
  FOREIGN KEY (streak_id) REFERENCES streaks(id) ON DELETE SET NULL;

ALTER TABLE streaks DROP CONSTRAINT IF EXISTS streaks_profile_id_fkey;
DROP INDEX IF EXISTS idx_streaks_profile_id;
ALTER TABLE streaks DROP COLUMN IF EXISTS profile_id;

-- 6. completed_nodes → progress_restrictions
ALTER TABLE completed_nodes DROP CONSTRAINT IF EXISTS completed_nodes_progress_id_fkey;

ALTER TABLE completed_nodes
  ADD CONSTRAINT completed_nodes_progress_id_fkey
  FOREIGN KEY (progress_id) REFERENCES progress_restrictions(id) ON DELETE SET NULL;

-- 7. game_sessions → history_games + games (1:1)
INSERT INTO history_games (id, progress_id, completed, created_at, user_id)
SELECT
  gs.id,
  gs.progress_id,
  gs.completed,
  COALESCE(gs.created_at, now()),
  gs.user_id
FROM game_sessions gs
WHERE gs.progress_id IS NOT NULL
ON CONFLICT (id) DO NOTHING;

INSERT INTO games (
  history_id,
  user_id,
  progress_id,
  game_type,
  node_id,
  accuracy,
  score,
  completed,
  started_at,
  completed_at,
  created_at,
  correct_answers,
  wrong_answers,
  duration_seconds,
  finished_at,
  client_run_id
)
SELECT
  gs.id,
  gs.user_id,
  gs.progress_id,
  gs.game_type,
  gs.node_id,
  gs.accuracy,
  gs.score,
  gs.completed,
  COALESCE(gs.started_at, gs.created_at, now()),
  gs.completed_at,
  COALESCE(gs.created_at, now()),
  gs.correct_answers,
  gs.wrong_answers,
  gs.duration_seconds,
  gs.finished_at,
  gs.client_run_id
FROM game_sessions gs
WHERE gs.progress_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM games g WHERE g.history_id = gs.id
  );

CREATE UNIQUE INDEX IF NOT EXISTS games_progress_client_run_id_unique
  ON games(progress_id, client_run_id)
  WHERE client_run_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_games_user_id ON games(user_id);
CREATE INDEX IF NOT EXISTS idx_games_progress_id ON games(progress_id);
CREATE INDEX IF NOT EXISTS idx_progress_restrictions_user_id ON progress_restrictions(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_streak_id ON profiles(streak_id);

-- 8. Eliminar tablas que no forman parte del MER
DROP TABLE IF EXISTS game_sessions CASCADE;
DROP TABLE IF EXISTS player_progress CASCADE;
DROP TABLE IF EXISTS player_streaks CASCADE;
DROP TABLE IF EXISTS player_profiles CASCADE;
DROP TABLE IF EXISTS unlocked_content CASCADE;
DROP TABLE IF EXISTS user_images CASCADE;
DROP TABLE IF EXISTS password_reset_tokens CASCADE;

-- images: tabla del MER (avatar); sin image_key obligatorio
ALTER TABLE images ALTER COLUMN image_key DROP NOT NULL;
