import dotenv from 'dotenv';
import { app } from './app';
import { scheduleOutboundEmailJob } from './modules/email/email.service';
import { emailConfig, isEmailDeliveryConfigured } from './modules/email/email.config';
import { warmUpLeaderboard } from './modules/leaderboard/leaderboard.service';

dotenv.config();

const port = Number.parseInt(process.env.BACKEND_PORT ?? '3000', 10);

app.listen(port, () => {
  console.log(`E-VIDENTE backend listening on port ${port}`);

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
