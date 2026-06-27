-- Leaderboard: meta inicial para scopes por restricción alimentaria.

INSERT INTO leaderboard_meta (scope, last_refreshed_at, row_count, duration_ms, current_generation)
VALUES
  ('restriction:CELIAQUIA', NULL, 0, 0, 0),
  ('restriction:VEG',       NULL, 0, 0, 0),
  ('restriction:VYG',       NULL, 0, 0, 0),
  ('restriction:KETO',      NULL, 0, 0, 0)
ON CONFLICT (scope) DO NOTHING;
