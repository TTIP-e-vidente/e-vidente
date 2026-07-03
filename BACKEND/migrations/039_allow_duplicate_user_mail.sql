-- Permite varias cuentas con el mismo correo.
-- El identificador unico de login sigue siendo username; mail queda como
-- canal de verificacion/notificacion y puede repetirse entre usuarios.
DROP INDEX IF EXISTS idx_users_mail_unique;
