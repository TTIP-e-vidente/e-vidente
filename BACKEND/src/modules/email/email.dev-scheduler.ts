import { emailConfig, isEmailDeliveryConfigured } from './email.config';
import { scheduleOutboundEmailJob } from './email.service';

const DEV_RECURRING_MS = 6 * 60 * 60 * 1000;

/**
 * En desarrollo con Express local, re-ejecuta la cola outbound cada 6 h.
 * Staging/producción: pg_cron en Supabase → Edge internal-job.
 */
export function scheduleDevRecurringEmailJobs(): void {
  if (process.env.NODE_ENV !== 'development') {
    return;
  }
  if (!isEmailDeliveryConfigured()) {
    return;
  }

  setInterval(() => {
    console.log('[email] dev recurring outbound job (rachas / reintentos / bienvenida pendiente)');
    scheduleOutboundEmailJob();
  }, DEV_RECURRING_MS);

  console.log(
    `[email] dev: cola outbound cada ${DEV_RECURRING_MS / 3600000}h (timezone ${emailConfig.timezone})`
  );
}
