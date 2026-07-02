-- Avatares en Supabase Storage (bucket privado; lectura/escritura vía Edge Functions + service role).

ALTER TABLE images
  ADD COLUMN IF NOT EXISTS storage_path TEXT;

COMMENT ON COLUMN images.storage_path IS
  'Ruta del objeto en bucket avatars. Si está seteado, data puede ser NULL (legacy base64 en data).';

-- El bucket solo existe en Supabase; en Postgres local (tests/dev) se omite
-- para que las migraciones corran desde cero sin errores.
DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NULL THEN
    RAISE NOTICE 'storage.buckets no existe (Postgres local): se omite el bucket avatars';
    RETURN;
  END IF;

  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES (
    'avatars',
    'avatars',
    false,
    3145728,
    ARRAY['image/png', 'image/jpeg', 'image/webp']::text[]
  )
  ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;
END $$;

CREATE INDEX IF NOT EXISTS idx_images_storage_path ON images (storage_path)
  WHERE storage_path IS NOT NULL;
