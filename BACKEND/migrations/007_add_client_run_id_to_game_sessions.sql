-- Migracion 007: idempotencia de sincronizacion por clientRunId.

ALTER TABLE game_sessions
  ADD COLUMN IF NOT EXISTS client_run_id VARCHAR(120) NULL;

CREATE UNIQUE INDEX IF NOT EXISTS game_sessions_progress_client_run_id_unique
  ON game_sessions(progress_id, client_run_id)
  WHERE client_run_id IS NOT NULL;
