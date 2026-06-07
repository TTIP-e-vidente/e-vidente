-- Agrega FK desde users hacia images para que cada usuario tenga una referencia
-- directa a su imagen de avatar. ON DELETE SET NULL: si se borra la imagen,
-- el usuario no se elimina.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS avatar_image_id UUID REFERENCES images(id) ON DELETE SET NULL;

-- Rellena la columna para usuarios que ya tienen imagen almacenada.
UPDATE users u
SET avatar_image_id = i.id
FROM images i
WHERE i.user_id = u.id
  AND u.avatar_image_id IS NULL;
