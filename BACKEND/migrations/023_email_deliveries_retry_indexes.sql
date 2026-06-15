-- Índices para exclusiones de dedupe y reintentos de envíos fallidos.

CREATE INDEX IF NOT EXISTS idx_email_deliveries_active_dedupe
  ON email_deliveries(user_id, template_key, dedupe_key)
  WHERE status IN ('sent', 'pending');

CREATE INDEX IF NOT EXISTS idx_email_deliveries_failed_retry
  ON email_deliveries(failed_at DESC)
  WHERE status = 'failed';
