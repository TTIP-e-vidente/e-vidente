-- Migración 005: Corregir constraints únicos de progreso y agregar índices faltantes
--
-- Problema: completed_nodes y unlocked_content tenían UNIQUE basado en user_id,
-- lo que impide que un jugador complete el mismo nodo o desbloquee el mismo
-- contenido bajo restricciones diferentes (ej: CELIAQUIA y VEG).
-- El modelo canónico establece que la unicidad debe ser por (progress_id, node_id)
-- y (progress_id, content_id) para respetar el aislamiento por restricción.
--
-- También se agregan índices faltantes sobre progress_id en game_sessions y
-- completed_nodes, necesarios para queries de progreso por sesión.
--
-- CONDICIONES DE SEGURIDAD:
-- - Las tablas completed_nodes, unlocked_content y game_sessions estaban vacías.
-- - No se borran datos.
-- - No se borran tablas.
-- - Se usan DO $$ para verificar existencia antes de crear constraints.

-- 1. Reemplazar UNIQUE(user_id, node_id) por UNIQUE(progress_id, node_id)
--    en completed_nodes.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'completed_nodes_user_node_unique'
  ) THEN
    ALTER TABLE completed_nodes DROP CONSTRAINT completed_nodes_user_node_unique;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'completed_nodes_progress_node_unique'
  ) THEN
    ALTER TABLE completed_nodes
      ADD CONSTRAINT completed_nodes_progress_node_unique
      UNIQUE (progress_id, node_id);
  END IF;
END $$;

-- 2. Reemplazar UNIQUE(user_id, content_id) por UNIQUE(progress_id, content_id)
--    en unlocked_content.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unlocked_content_user_content_unique'
  ) THEN
    ALTER TABLE unlocked_content DROP CONSTRAINT unlocked_content_user_content_unique;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unlocked_content_progress_content_unique'
  ) THEN
    ALTER TABLE unlocked_content
      ADD CONSTRAINT unlocked_content_progress_content_unique
      UNIQUE (progress_id, content_id);
  END IF;
END $$;

-- 3. Agregar índice faltante en game_sessions.progress_id
CREATE INDEX IF NOT EXISTS idx_game_sessions_progress_id
  ON game_sessions(progress_id);

-- 4. Agregar índice faltante en completed_nodes.progress_id
CREATE INDEX IF NOT EXISTS idx_completed_nodes_progress_id
  ON completed_nodes(progress_id);
