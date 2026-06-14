-- Auditoría extendida de envíos de email: estado, destinatario, asunto y errores.

ALTER TABLE email_deliveries
  ADD COLUMN IF NOT EXISTS recipient_email VARCHAR(255),
  ADD COLUMN IF NOT EXISTS subject VARCHAR(255),
  ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS provider_message_id TEXT,
  ADD COLUMN IF NOT EXISTS error_message TEXT,
  ADD COLUMN IF NOT EXISTS failed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 1;

ALTER TABLE email_deliveries
  ALTER COLUMN sent_at DROP NOT NULL;

UPDATE email_deliveries
SET
  status = 'sent',
  created_at = COALESCE(created_at, sent_at, now())
WHERE status = 'sent' OR sent_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_email_deliveries_status ON email_deliveries(status);
CREATE INDEX IF NOT EXISTS idx_email_deliveries_created_at ON email_deliveries(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_deliveries_template_key ON email_deliveries(template_key);
