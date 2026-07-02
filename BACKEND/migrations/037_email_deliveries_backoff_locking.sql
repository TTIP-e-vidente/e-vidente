-- Outbox más sólido: backoff entre reintentos y locking cooperativo para que
-- dos jobs (Express legacy / Edge internal-job) no procesen el mismo delivery.
--
-- next_attempt_at: momento a partir del cual el delivery fallido puede reintentarse.
--   attempt 1: inmediato | attempt 2: +10 min | attempt 3: +1 h | attempt 4: +6 h
-- last_attempt_at: último intento real de envío.
-- locked_at / locked_by: claim cooperativo del job que está procesando la fila.

ALTER TABLE email_deliveries ADD COLUMN IF NOT EXISTS next_attempt_at TIMESTAMPTZ;
ALTER TABLE email_deliveries ADD COLUMN IF NOT EXISTS last_attempt_at TIMESTAMPTZ;
ALTER TABLE email_deliveries ADD COLUMN IF NOT EXISTS locked_at TIMESTAMPTZ;
ALTER TABLE email_deliveries ADD COLUMN IF NOT EXISTS locked_by TEXT;

-- Reintentos vencidos se buscan por status + next_attempt_at.
CREATE INDEX IF NOT EXISTS idx_email_deliveries_retry_due
  ON email_deliveries(next_attempt_at ASC)
  WHERE status = 'failed';

-- Backfill: deliveries fallidos existentes quedan elegibles de inmediato.
UPDATE email_deliveries
SET next_attempt_at = COALESCE(next_attempt_at, failed_at, created_at)
WHERE status = 'failed'
  AND next_attempt_at IS NULL;
