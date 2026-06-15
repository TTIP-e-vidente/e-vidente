import dotenv from 'dotenv';
import { pool } from '../src/config/database';
import { runRetryFailedEmailJob } from '../src/modules/email/email.service';

dotenv.config();

async function run(): Promise<void> {
  try {
    const result = await runRetryFailedEmailJob();
    console.log('[email:retry-failed] completed', JSON.stringify(result));
  } finally {
    await pool.end();
  }
}

run().catch((error) => {
  console.error('[email:retry-failed] failed', error);
  process.exit(1);
});
