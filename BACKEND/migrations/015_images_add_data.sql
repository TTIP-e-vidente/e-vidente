-- Agrega columnas para almacenar el avatar del usuario como base64.
-- data: imagen codificada en base64.
-- mime_type: tipo MIME (image/png, image/jpeg, image/webp).
ALTER TABLE images ADD COLUMN IF NOT EXISTS data TEXT;
ALTER TABLE images ADD COLUMN IF NOT EXISTS mime_type VARCHAR(20);

-- Elimina filas duplicadas por user_id (mantiene la más reciente) antes de agregar la constraint.
DELETE FROM images
WHERE id NOT IN (
  SELECT DISTINCT ON (user_id) id
  FROM images
  ORDER BY user_id, updated_at DESC
);

-- Agrega UNIQUE solo si no existe ya.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'images_user_id_unique' AND conrelid = 'images'::regclass
  ) THEN
    ALTER TABLE images ADD CONSTRAINT images_user_id_unique UNIQUE (user_id);
  END IF;
END
$$;
