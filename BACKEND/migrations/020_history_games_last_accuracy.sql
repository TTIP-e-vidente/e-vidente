-- Persiste la precisión de la última corrida por nodo, separada de best_accuracy.

ALTER TABLE history_games
  ADD COLUMN IF NOT EXISTS last_accuracy NUMERIC(5, 2);

UPDATE history_games hg
SET last_accuracy = sub.accuracy
FROM (
  SELECT DISTINCT ON (history_id) history_id, accuracy
  FROM games
  ORDER BY history_id, created_at DESC
) sub
WHERE hg.id = sub.history_id;

UPDATE history_games
SET last_accuracy = best_accuracy
WHERE last_accuracy IS NULL
  AND best_accuracy IS NOT NULL;
