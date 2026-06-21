-- Intentos fallidos de OTP persistidos (multi-instancia y sobrevive reinicios).

ALTER TABLE email_verification_codes
  ADD COLUMN IF NOT EXISTS failed_attempt_count INTEGER NOT NULL DEFAULT 0;
