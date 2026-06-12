-- La racha necesita dos datos que no se persistían:
--   1. games.local_day: día calendario LOCAL del jugador al terminar la partida.
--      El recálculo de racha usaba el día UTC; para un jugador en UTC-3 toda
--      partida posterior a las 21:00 caía en el día UTC siguiente y la racha
--      se corría un día (verde "ya activaste tu racha" sin haber jugado).
--   2. streaks.last_activity_at: instante real de la última actividad. El
--      cliente usaba updated_at (hora del sync) como proxy y cualquier sync
--      del día marcaba la racha como activa.

ALTER TABLE games
  ADD COLUMN IF NOT EXISTS local_day DATE;

ALTER TABLE streaks
  ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

-- Backfill: instante de la última partida completada de cada usuario.
UPDATE streaks s
SET last_activity_at = ult.max_finished
FROM (
  SELECT p.streak_id, MAX(COALESCE(g.finished_at, g.created_at)) AS max_finished
  FROM games g
  JOIN profiles p ON p.user_id = g.user_id
  WHERE g.completed = true
    AND p.streak_id IS NOT NULL
  GROUP BY p.streak_id
) ult
WHERE s.id = ult.streak_id
  AND s.last_activity_at IS NULL;
