-- Verificación de email por código OTP de 6 dígitos.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS mail_verified_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS email_verification_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash VARCHAR(255) NOT NULL,
  target_mail VARCHAR(255) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_verification_codes_user_id
  ON email_verification_codes(user_id);

CREATE INDEX IF NOT EXISTS idx_email_verification_codes_active
  ON email_verification_codes(user_id, expires_at DESC)
  WHERE used_at IS NULL;
