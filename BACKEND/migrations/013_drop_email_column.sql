-- La columna original era email (001), y en 002 se agrego mail.
-- El codigo usa mail; email queda como columna huerfana.
-- El index idx_users_email se elimina automaticamente con la columna.
ALTER TABLE users DROP COLUMN IF EXISTS email;
