import dotenv from 'dotenv';
import { pool } from '../src/config/database';
import { runStreakEmailJob } from '../src/modules/email/email.service';

dotenv.config();

async function run(): Promise<void> {
  try {
    const result = await runStreakEmailJob();
    console.log('[email:streaks] completed', JSON.stringify(result));
  } finally {
    await pool.end();
  }
}

run().catch((error) => {
  console.error('[email:streaks] failed', error);
  process.exit(1);
});
