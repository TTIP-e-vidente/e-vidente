-- Limpieza idempotente de rachas huérfanas.
-- El modelo canónico es profiles.streak_id -> streaks.id; cualquier streak no
-- referenciado por profiles no pertenece a ninguna cuenta y no debe quedar vivo.
DELETE FROM streaks s
WHERE NOT EXISTS (
  SELECT 1
  FROM profiles p
  WHERE p.streak_id = s.id
);

-- Defensa adicional: una misma racha no puede quedar compartida por dos perfiles.
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_streak_id_unique
  ON profiles(streak_id)
  WHERE streak_id IS NOT NULL;
