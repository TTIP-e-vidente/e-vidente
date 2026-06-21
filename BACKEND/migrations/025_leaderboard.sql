-- Leaderboard: tabla de snapshots materializados para rankings de jugadores.
--
-- Diseño: snapshot materializado (no view en vivo) para que las queries de
-- leaderboard sean O(1) contra esta tabla en lugar de recalcular sobre
-- millones de rows de games/profiles en cada request.
--
-- Scopes disponibles:
--   'global_xp'            → ranking por XP total (profiles.exp_count)
--   'streak'               → ranking por mejor racha histórica (streaks.best_count)
--   'restriction:{type}'   → ranking por XP en una restricción específica

CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
  id           UUID         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  scope        VARCHAR(80)  NOT NULL,
  user_id      UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  username     VARCHAR(255) NOT NULL,
  display_name VARCHAR(255),
  avatar_key   VARCHAR(255),
  score        BIGINT       NOT NULL DEFAULT 0,
  rank         INTEGER      NOT NULL,
  computed_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Top-N query: scope + rank
CREATE INDEX IF NOT EXISTS idx_leaderboard_scope_rank
  ON leaderboard_snapshots(scope, rank);

-- Posición propia del usuario autenticado
CREATE INDEX IF NOT EXISTS idx_leaderboard_scope_user
  ON leaderboard_snapshots(scope, user_id);

-- Frescura del snapshot
CREATE INDEX IF NOT EXISTS idx_leaderboard_computed_at
  ON leaderboard_snapshots(scope, computed_at DESC);
