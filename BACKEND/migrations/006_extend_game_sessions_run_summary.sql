-- Migración 006: Extender game_sessions con campos del contrato RunSummary
--
-- Agrega correct_answers, wrong_answers, duration_seconds y finished_at
-- a game_sessions para soportar el contrato completo que Godot enviará.
--
-- DECISIÓN sobre timestamps:
--   finished_at  → marca de tiempo que provee el cliente (Godot).
--   completed_at → sigue siendo el timestamp del servidor (cuándo el backend
--                  procesó la sesión). Ambos conviven para trazabilidad.
--
-- CONDICIONES DE SEGURIDAD:
--   - ADD COLUMN IF NOT EXISTS: no modifica columnas existentes ni borra datos.
--   - DO $$ con verificación en pg_constraint: idempotente para constraints.
--   - No se borran tablas ni datos.

ALTER TABLE game_sessions
  ADD COLUMN IF NOT EXISTS correct_answers   INTEGER     NULL,
  ADD COLUMN IF NOT EXISTS wrong_answers     INTEGER     NULL,
  ADD COLUMN IF NOT EXISTS duration_seconds  INTEGER     NULL,
  ADD COLUMN IF NOT EXISTS finished_at       TIMESTAMPTZ NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'game_sessions_correct_answers_non_negative'
  ) THEN
    ALTER TABLE game_sessions
      ADD CONSTRAINT game_sessions_correct_answers_non_negative
      CHECK (correct_answers >= 0);
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'game_sessions_wrong_answers_non_negative'
  ) THEN
    ALTER TABLE game_sessions
      ADD CONSTRAINT game_sessions_wrong_answers_non_negative
      CHECK (wrong_answers >= 0);
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'game_sessions_duration_seconds_non_negative'
  ) THEN
    ALTER TABLE game_sessions
      ADD CONSTRAINT game_sessions_duration_seconds_non_negative
      CHECK (duration_seconds >= 0);
  END IF;
END;
$$;
