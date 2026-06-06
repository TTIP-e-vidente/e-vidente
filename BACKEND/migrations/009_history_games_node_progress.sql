-- history_games = progreso por nodo dentro de una restriccion (ej. celiaquia).
-- games = cada partida jugada en ese nodo.
-- completed_nodes se absorbe en history_games.

ALTER TABLE history_games
  ADD COLUMN IF NOT EXISTS node_id VARCHAR(120),
  ADD COLUMN IF NOT EXISTS node_type VARCHAR(80),
  ADD COLUMN IF NOT EXISTS best_score INTEGER,
  ADD COLUMN IF NOT EXISTS best_accuracy NUMERIC(5, 2),
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

ALTER TABLE progress_restrictions
  ADD COLUMN IF NOT EXISTS map_completed BOOLEAN NOT NULL DEFAULT false;

-- Enlazar history_games viejos (1 por partida) con el node_id de su game
UPDATE history_games hg
SET
  node_id = g.node_id,
  user_id = COALESCE(hg.user_id, g.user_id),
  completed = CASE WHEN hg.completed OR g.completed THEN true ELSE hg.completed END,
  best_score = GREATEST(COALESCE(hg.best_score, 0), COALESCE(g.score, 0)),
  best_accuracy = GREATEST(COALESCE(hg.best_accuracy, 0), COALESCE(g.accuracy, 0)),
  completed_at = COALESCE(hg.completed_at, g.completed_at, g.created_at)
FROM games g
WHERE g.history_id = hg.id
  AND g.node_id IS NOT NULL
  AND hg.node_id IS NULL;

-- Migrar completed_nodes → history_games
INSERT INTO history_games (
  progress_id,
  user_id,
  node_id,
  node_type,
  completed,
  best_score,
  best_accuracy,
  completed_at,
  created_at
)
SELECT
  cn.progress_id,
  cn.user_id,
  cn.node_id,
  cn.node_type,
  true,
  cn.best_score,
  cn.best_accuracy,
  cn.completed_at,
  cn.completed_at
FROM completed_nodes cn
WHERE cn.progress_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM history_games hg
    WHERE hg.progress_id = cn.progress_id
      AND hg.node_id = cn.node_id
  );

-- Mejor marca si completed_nodes tenia mejor precision
UPDATE history_games hg
SET
  best_score = GREATEST(COALESCE(hg.best_score, 0), COALESCE(cn.best_score, 0)),
  best_accuracy = GREATEST(COALESCE(hg.best_accuracy, 0), COALESCE(cn.best_accuracy, 0)),
  completed = true,
  completed_at = COALESCE(hg.completed_at, cn.completed_at)
FROM completed_nodes cn
WHERE hg.progress_id = cn.progress_id
  AND hg.node_id = cn.node_id;

-- Reapuntar games al history_games del nodo (no al wrapper viejo)
UPDATE games g
SET history_id = hg.id
FROM history_games hg
WHERE hg.progress_id = g.progress_id
  AND hg.node_id = g.node_id
  AND g.node_id IS NOT NULL
  AND g.history_id <> hg.id;

-- Borrar history_games huerfanos sin nodo
DELETE FROM history_games hg
WHERE hg.node_id IS NULL
  AND NOT EXISTS (SELECT 1 FROM games g WHERE g.history_id = hg.id);

-- Quedarse con el history_games mas viejo por nodo
DELETE FROM history_games a
USING history_games b
WHERE a.progress_id = b.progress_id
  AND a.node_id IS NOT NULL
  AND a.node_id = b.node_id
  AND a.created_at > b.created_at;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'history_games_progress_node_unique'
  ) THEN
    ALTER TABLE history_games
      ADD CONSTRAINT history_games_progress_node_unique UNIQUE (progress_id, node_id);
  END IF;
END $$;

DROP TABLE IF EXISTS completed_nodes CASCADE;
