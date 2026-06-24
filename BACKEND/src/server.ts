import dotenv from 'dotenv';
import { app } from './app';
import { scheduleOutboundEmailJob } from './modules/email/email.service';
import { emailConfig, isEmailDeliveryConfigured } from './modules/email/email.config';
import { warmUpLeaderboard } from './modules/leaderboard/leaderboard.service';

dotenv.config();

const port = Number.parseInt(process.env.BACKEND_PORT ?? '3010', 10);

function logEmailStartupStatus(): void {
  if (process.env.NODE_ENV === 'test') {
    return;
  }
  if (!emailConfig.enabled) {
    console.warn('[email] EMAIL_ENABLED=false — no se enviarán mails de verificación ni bienvenida');
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
  console.log('[email] Brevo configurado — verificación y bienvenida activas');
}

app.listen(port, () => {
  console.log(`E-VIDENTE backend listening on port ${port}`);
  logEmailStartupStatus();

  if (isEmailDeliveryConfigured() && process.env.NODE_ENV !== 'test') {
    if (emailConfig.processOnStartup) {
      console.log('[email] processing outbound queue on startup');
      scheduleOutboundEmailJob();
    }
  }

  if (process.env.NODE_ENV !== 'test') {
    warmUpLeaderboard();
  }
});
