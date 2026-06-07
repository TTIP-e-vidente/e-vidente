-- Elimina streaks no referenciados por ningún profile (creados por race conditions
-- en ensureStreak antes de que se agregara el lock por fila).
DELETE FROM streaks
WHERE id NOT IN (
  SELECT streak_id
  FROM profiles
  WHERE streak_id IS NOT NULL
);
