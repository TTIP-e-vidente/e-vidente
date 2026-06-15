import dotenv from 'dotenv';
import { pool } from '../src/config/database';
import { runOutboundEmailJob } from '../src/modules/email/email.service';

dotenv.config();

async function run(): Promise<void> {
  try {
    const result = await runOutboundEmailJob();
    console.log('[email:run-local] completed', JSON.stringify(result));
  } finally {
    await pool.end();
  }
}

run().catch((error) => {
  console.error('[email:run-local] failed', error);
  process.exit(1);
});
