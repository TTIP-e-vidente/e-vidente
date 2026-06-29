import { loadEnvFile } from './config/load-env';
import { app } from './app';
import { scheduleOutboundEmailJob } from './modules/email/email.service';
import { runBrevoStartupProbe } from './modules/email/email.brevo-probe';
import { scheduleDevRecurringEmailJobs } from './modules/email/email.dev-scheduler';
import { emailConfig, isEmailDeliveryConfigured } from './modules/email/email.config';
import {
  canReachSupabaseEmailEdge,
  isSupabaseEmailEdgeMode,
  shouldRunExpressEmailDelivery,
} from './config/supabase-email-mode';
import { warmUpLeaderboard } from './modules/leaderboard/leaderboard.service';
import { isRemotePostgres } from './config/postgresPoolConfig';
import { verifyRemotePostgresOnStartup } from './startup/verify-remote-postgres';

loadEnvFile();

const port = Number.parseInt(process.env.BACKEND_PORT ?? '3010', 10);

function logEmailStartupStatus(): void {
  if (process.env.NODE_ENV === 'test') {
    return;
  }
  if (!emailConfig.enabled) {
    console.warn('[email] EMAIL_ENABLED=false — no se enviarán mails de verificación ni bienvenida');
    return;
  }
  if (isSupabaseEmailEdgeMode()) {
    if (canReachSupabaseEmailEdge()) {
      console.log('[email] Supabase Edge — verify OTP y jobs (pg_cron → internal-job)');
    } else {
      console.warn(
        '[email] Modo Supabase Edge activo pero falta SUPABASE_ANON_KEY — npm run configure:supabase-keys'
      );
    }
    return;
  }
  if (!isEmailDeliveryConfigured()) {
    console.warn(
      '[email] Brevo incompleto: configurá BREVO_API_KEY y BREVO_SENDER_EMAIL en BACKEND/.env'
    );
    if (process.env.NODE_ENV === 'development') {
      console.warn('[email] Modo dev: los códigos OTP se loguean en esta consola (evento dev_code)');
    }
    return;
  }
  console.log('[email] Brevo en Express — verificación y bienvenida activas (solo Postgres local)');
}

async function startServer(): Promise<void> {
  await verifyRemotePostgresOnStartup();

  app.listen(port, async () => {
    console.log(`E-VIDENTE backend listening on port ${port}`);
    logEmailStartupStatus();

    if (
      !isSupabaseEmailEdgeMode() &&
      isEmailDeliveryConfigured() &&
      process.env.NODE_ENV !== 'test'
    ) {
      void runBrevoStartupProbe();
    }

    if (isRemotePostgres() && process.env.NODE_ENV !== 'test') {
      console.log(
        `[dev] Godot → http://localhost:${port} (juego/config/backend.local.json)`
      );
    }

    if (
      shouldRunExpressEmailDelivery() &&
      isEmailDeliveryConfigured() &&
      process.env.NODE_ENV !== 'test'
    ) {
      if (emailConfig.processOnStartup) {
        console.log('[email] processing outbound queue on startup');
        scheduleOutboundEmailJob();
      }
      scheduleDevRecurringEmailJobs();
    }

    if (process.env.NODE_ENV !== 'test') {
      warmUpLeaderboard();
    }
  });
}

startServer().catch((error) => {
  console.error('[startup] falló:', error);
  process.exit(1);
});
