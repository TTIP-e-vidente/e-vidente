import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import { PoolClient } from 'pg';
import { pool } from '../src/config/database';
import { authConfig } from '../src/config/auth';
import * as profileRepository from '../src/modules/profile/profile.repository';
import * as streakRepository from '../src/modules/streak/streak.repository';
import {
  getTodayInConfiguredTimezone,
  runStreakEmailJob
} from '../src/modules/email/email.service';
import * as emailRepository from '../src/modules/email/email.repository';

dotenv.config();

const DEMO_USERNAME = process.env.STREAK_DEMO_USERNAME ?? 'streak_demo';
const DEMO_NAME = process.env.STREAK_DEMO_NAME ?? 'Demo Racha';
const DEMO_MAIL = process.env.STREAK_DEMO_MAIL ?? 'streak.demo@evidente.test';
const DEMO_PASSWORD = process.env.STREAK_DEMO_PASSWORD ?? 'Password123';
const DEMO_STREAK_COUNT = Math.max(
  1,
  Number.parseInt(process.env.STREAK_DEMO_COUNT ?? '7', 10) || 7
);

function shiftDateIso(dateIso: string, dayDelta: number): string {
  const anchor = new Date(`${dateIso}T12:00:00.000Z`);
  anchor.setUTCDate(anchor.getUTCDate() + dayDelta);
  return anchor.toISOString().slice(0, 10);
}

async function upsertDemoUser(client: PoolClient, passwordHash: string): Promise<string> {
  const result = await client.query<{ id: string }>(
    `
      INSERT INTO users (
        username,
        name,
        display_name,
        mail,
        password_hash,
        email_notifications_enabled
      )
      VALUES ($1, $2, $2, $3, $4, true)
      ON CONFLICT (username)
      DO UPDATE SET
        name = EXCLUDED.name,
        display_name = EXCLUDED.display_name,
        mail = EXCLUDED.mail,
        password_hash = EXCLUDED.password_hash,
        email_notifications_enabled = true,
        updated_at = now()
      RETURNING id;
    `,
    [DEMO_USERNAME, DEMO_NAME, DEMO_MAIL, passwordHash]
  );

  return result.rows[0].id;
}

async function seedStreakAtRiskDemo(): Promise<{
  userId: string;
  today: string;
  yesterday: string;
  streakCount: number;
}> {
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, authConfig.bcryptSaltRounds);
  const today = getTodayInConfiguredTimezone();
  const yesterday = shiftDateIso(today, -1);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const userId = await upsertDemoUser(client, passwordHash);
    const profile = await profileRepository.ensureProfile(client, userId, 'CELIAQUIA');
    await streakRepository.ensureStreak(client, userId, profile.id);

    await client.query(
      `
        UPDATE streaks s
        SET
          current_count = $2,
          best_count = GREATEST(s.best_count, $2),
          last_activity_day = $3::date,
          last_activity_at = ($3::date + time '20:00') AT TIME ZONE 'America/Argentina/Buenos_Aires',
          updated_at = now()
        FROM profiles p
        WHERE p.user_id = $1
          AND p.streak_id = s.id;
      `,
      [userId, DEMO_STREAK_COUNT, yesterday]
    );

    await client.query(
      `
        DELETE FROM email_deliveries
        WHERE user_id = $1
          AND template_key = 'streak_at_risk'
          AND dedupe_key = 'at_risk:' || $2;
      `,
      [userId, today]
    );

    await client.query('COMMIT');
    return { userId, today, yesterday, streakCount: DEMO_STREAK_COUNT };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function run(): Promise<void> {
  const seeded = await seedStreakAtRiskDemo();

  const candidates = await emailRepository.findStreakAtRiskCandidates(seeded.today);
  const isCandidate = candidates.some((row) => row.userId === seeded.userId);

  console.log(
    JSON.stringify(
      {
        status: 'seeded',
        username: DEMO_USERNAME,
        mail: DEMO_MAIL,
        password: DEMO_PASSWORD,
        streakCount: seeded.streakCount,
        lastActivityDay: seeded.yesterday,
        referenceToday: seeded.today,
        isStreakAtRiskCandidate: isCandidate
      },
      null,
      2
    )
  );

  if (!isCandidate) {
    console.warn('[seed:streak-email-demo] Usuario creado pero no aparece como candidato at_risk.');
    return;
  }

  if (process.argv.includes('--run-job')) {
    const jobResult = await runStreakEmailJob(seeded.today);
    console.log('[seed:streak-email-demo] email:streaks', JSON.stringify(jobResult));
  } else {
    console.log(
      '[seed:streak-email-demo] Siguiente paso: npm run email:streaks (o re-ejecutar con --run-job)'
    );
  }
}

run()
  .catch((error) => {
    console.error('[seed:streak-email-demo] failed', error);
    process.exit(1);
  })
  .finally(async () => {
    await pool.end();
  });
