-- Mejoras de eficiencia al sistema de leaderboard:
--
-- 1. Columna `generation` para swap atómico sin downtime (elimina ventana vacía)
-- 2. Tabla `leaderboard_meta` para tracking de salud del refresh
-- 3. Índice covering que incluye score para index-only scans en el top-N query

-- 1. Columna de generación para el swap atómico
ALTER TABLE leaderboard_snapshots
  ADD COLUMN IF NOT EXISTS generation INTEGER NOT NULL DEFAULT 1;

-- 2. Índice covering: scope + rank + score + campos de respuesta → index-only scan
--    Reemplaza el índice básico de scope/rank con uno que cubra los campos del SELECT
DROP INDEX IF EXISTS idx_leaderboard_scope_rank;
CREATE INDEX IF NOT EXISTS idx_leaderboard_scope_rank_covering
  ON leaderboard_snapshots(scope, rank)
  INCLUDE (user_id, username, display_name, avatar_key, score, computed_at, generation);

-- Índice para el swap: necesitamos filtrar por generation durante la limpieza
CREATE INDEX IF NOT EXISTS idx_leaderboard_scope_generation
  ON leaderboard_snapshots(scope, generation);

-- 3. Tabla de metadatos del leaderboard (tracking de salud del refresh)
CREATE TABLE IF NOT EXISTS leaderboard_meta (
  scope             VARCHAR(80)  NOT NULL PRIMARY KEY,
  last_refreshed_at TIMESTAMPTZ,
  row_count         INTEGER      NOT NULL DEFAULT 0,
  duration_ms       INTEGER      NOT NULL DEFAULT 0,
  current_generation INTEGER     NOT NULL DEFAULT 0,
  error_message     TEXT
);

-- Inicializar filas de meta para los scopes existentes
INSERT INTO leaderboard_meta (scope, last_refreshed_at, row_count, duration_ms, current_generation)
VALUES
  ('global_xp', NULL, 0, 0, 0),
  ('streak',    NULL, 0, 0, 0)
ON CONFLICT (scope) DO NOTHING;
