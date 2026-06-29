import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';
import {
  buildStreakAtRiskEmail,
  buildStreakLostEmail,
  buildWelcomeEmail,
  isEmailDeliveryConfigured,
  type EmailMessage,
} from '../brevo.ts';
import {
  deliverTrackedEmail,
  expireStalePendingDeliveries,
  getTodayInTimezone,
  markWelcomeEmailSent,
  type DeliveryBatchStats,
} from '../delivery.ts';
import { withDb } from '../db.ts';
import { refreshAllLeaderboards } from '../services/leaderboard-refresh.ts';

interface StreakCandidate {
  userId: string;
  mail: string;
  name: string;
  streakId: string;
  currentCount: number;
}

function emailConfig() {
  return {
    timezone: Deno.env.get('EMAIL_TIMEZONE')?.trim() || 'America/Argentina/Buenos_Aires',
    staleMinutes: Number(Deno.env.get('EMAIL_PENDING_STALE_MINUTES') ?? '15'),
    retryMaxAttempts: Number(Deno.env.get('EMAIL_RETRY_MAX_ATTEMPTS') ?? '3'),
    retryMaxAgeHours: Number(Deno.env.get('EMAIL_RETRY_MAX_AGE_HOURS') ?? '48'),
    retryBatchLimit: Number(Deno.env.get('EMAIL_RETRY_BATCH_LIMIT') ?? '50'),
    welcomeBatchLimit: Number(Deno.env.get('EMAIL_PENDING_WELCOME_BATCH_LIMIT') ?? '25'),
  };
}

async function findUserStreakCount(db: Client, userId: string): Promise<number> {
  const result = await db.queryObject<{ current_count: number }>(
    `
      SELECT s.current_count
      FROM profiles p
      JOIN streaks s ON s.id = p.streak_id
      WHERE p.user_id = $1
      LIMIT 1;
    `,
    [userId],
  );
  return Math.max(1, result.rows[0]?.current_count ?? 1);
}

async function findStreakAtRisk(db: Client, today: string): Promise<StreakCandidate[]> {
  const result = await db.queryObject<{
    user_id: string;
    mail: string;
    name: string;
    streak_id: string;
    current_count: number;
  }>(
    `
      SELECT u.id AS user_id, u.mail, u.name, s.id AS streak_id, s.current_count
      FROM users u
      JOIN profiles p ON p.user_id = u.id
      JOIN streaks s ON s.id = p.streak_id
      WHERE u.mail IS NOT NULL
        AND u.mail_verified_at IS NOT NULL
        AND u.email_notifications_enabled = true
        AND s.current_count > 0
        AND s.last_activity_day = ($1::date - INTERVAL '1 day')::date
        AND NOT EXISTS (
          SELECT 1 FROM email_deliveries ed
          WHERE ed.user_id = u.id
            AND ed.template_key = 'streak_at_risk'
            AND ed.dedupe_key = 'at_risk:' || $1
            AND ed.status IN ('sent', 'pending')
        );
    `,
    [today],
  );
  return result.rows.map((r) => ({
    userId: r.user_id,
    mail: r.mail,
    name: r.name,
    streakId: r.streak_id,
    currentCount: r.current_count,
  }));
}

async function findStreakLost(db: Client, today: string): Promise<StreakCandidate[]> {
  const result = await db.queryObject<{
    user_id: string;
    mail: string;
    name: string;
    streak_id: string;
    current_count: number;
    last_activity_day: string;
  }>(
    `
      SELECT u.id AS user_id, u.mail, u.name, s.id AS streak_id, s.current_count,
             to_char(s.last_activity_day, 'YYYY-MM-DD') AS last_activity_day
      FROM users u
      JOIN profiles p ON p.user_id = u.id
      JOIN streaks s ON s.id = p.streak_id
      WHERE u.mail IS NOT NULL
        AND u.mail_verified_at IS NOT NULL
        AND u.email_notifications_enabled = true
        AND s.current_count > 0
        AND s.last_activity_day <= ($1::date - INTERVAL '2 days')::date
        AND NOT EXISTS (
          SELECT 1 FROM email_deliveries ed
          WHERE ed.user_id = u.id
            AND ed.template_key = 'streak_lost'
            AND ed.dedupe_key = 'lost:' || to_char(s.last_activity_day, 'YYYY-MM-DD')
            AND ed.status IN ('sent', 'pending')
        );
    `,
    [today],
  );
  return result.rows.map((r) => ({
    userId: r.user_id,
    mail: r.mail,
    name: r.name,
    streakId: r.streak_id,
    currentCount: r.current_count,
    lastActivityDay: r.last_activity_day,
  }));
}

async function reconcileExpiredStreaks(db: Client, today: string): Promise<number> {
  const result = await db.queryObject(
    `
      UPDATE streaks s
      SET current_count = 0, updated_at = now()
      FROM profiles p
      WHERE p.streak_id = s.id
        AND s.current_count > 0
        AND s.last_activity_day <= ($1::date - INTERVAL '2 days')::date
      RETURNING s.id;
    `,
    [today],
  );
  return result.rowCount ?? 0;
}

async function batchDeliver(
  candidates: Array<{
    userId: string;
    mail: string;
    name: string;
    templateKey: string;
    dedupeKey: string;
    message: EmailMessage;
    afterSent?: (db: Client) => Promise<void>;
  }>,
): Promise<DeliveryBatchStats> {
  const stats: DeliveryBatchStats = {
    attempted: candidates.length,
    sent: 0,
    failed: 0,
    skipped: 0,
  };
  for (const c of candidates) {
    const result = await deliverTrackedEmail({
      userId: c.userId,
      templateKey: c.templateKey,
      dedupeKey: c.dedupeKey,
      message: c.message,
      afterSent: c.afterSent,
    });
    if (result === 'sent') stats.sent += 1;
    else if (result === 'failed') stats.failed += 1;
    else stats.skipped += 1;
  }
  return stats;
}

export async function runStreakAtRiskEmailJob(referenceDate?: string) {
  if (!isEmailDeliveryConfigured()) {
    return { skipped: true, reason: 'brevo_not_configured' };
  }
  const cfg = emailConfig();
  const today = referenceDate ?? getTodayInTimezone(cfg.timezone);

  return withDb(async (db) => {
    const expiredPending = await expireStalePendingDeliveries(db, cfg.staleMinutes);
    const atRiskRows = await findStreakAtRisk(db, today);
    const atRisk = await batchDeliver(
      atRiskRows.map((c) => ({
        userId: c.userId,
        mail: c.mail,
        name: c.name,
        templateKey: 'streak_at_risk',
        dedupeKey: `at_risk:${today}`,
        message: buildStreakAtRiskEmail(c.name, c.mail, c.currentCount),
      })),
    );
    return { today, expiredPending, atRisk };
  });
}

export async function runStreakLostEmailJob(referenceDate?: string) {
  if (!isEmailDeliveryConfigured()) {
    return { skipped: true, reason: 'brevo_not_configured' };
  }
  const cfg = emailConfig();
  const today = referenceDate ?? getTodayInTimezone(cfg.timezone);

  return withDb(async (db) => {
    const expiredPending = await expireStalePendingDeliveries(db, cfg.staleMinutes);
    const lostRows = await findStreakLost(db, today);
    const lost = await batchDeliver(
      lostRows.map((c) => ({
        userId: c.userId,
        mail: c.mail,
        name: c.name,
        templateKey: 'streak_lost',
        dedupeKey: `lost:${(c as { lastActivityDay?: string }).lastActivityDay ?? today}`,
        message: buildStreakLostEmail(c.name, c.mail, c.currentCount),
      })),
    );
    const reconciledStreaks = await reconcileExpiredStreaks(db, today);
    return { today, expiredPending, lost, reconciledStreaks };
  });
}

export async function runStreakEmailJob(referenceDate?: string) {
  const atRisk = await runStreakAtRiskEmailJob(referenceDate);
  const lost = await runStreakLostEmailJob(referenceDate);
  if ('skipped' in atRisk && atRisk.skipped) {
    return atRisk;
  }
  if ('skipped' in lost && lost.skipped) {
    return lost;
  }
  return {
    today: (atRisk as { today: string }).today,
    expiredPending:
      ((atRisk as { expiredPending: number }).expiredPending ?? 0)
      + ((lost as { expiredPending: number }).expiredPending ?? 0),
    atRisk: (atRisk as { atRisk: DeliveryBatchStats }).atRisk,
    lost: (lost as { lost: DeliveryBatchStats }).lost,
    reconciledStreaks: (lost as { reconciledStreaks: number }).reconciledStreaks,
  };
}

export async function runRetryFailedEmailJob() {
  if (!isEmailDeliveryConfigured()) {
    return { skipped: true, reason: 'brevo_not_configured' };
  }
  const cfg = emailConfig();

  return withDb(async (db) => {
    const expiredPending = await expireStalePendingDeliveries(db, cfg.staleMinutes);
    const retries = await db.queryObject<{
      id: string;
      user_id: string;
      template_key: string;
      dedupe_key: string;
      recipient_email: string;
    }>(
      `
        SELECT id, user_id, template_key, dedupe_key, recipient_email
        FROM email_deliveries ed
        WHERE status = 'failed'
          AND recipient_email IS NOT NULL
          AND attempt_count < $1
          AND failed_at >= now() - ($2::text || ' hours')::interval
        ORDER BY failed_at ASC
        LIMIT $3;
      `,
      [cfg.retryMaxAttempts, String(cfg.retryMaxAgeHours), cfg.retryBatchLimit],
    );

    const stats: DeliveryBatchStats = {
      attempted: retries.rows.length,
      sent: 0,
      failed: 0,
      skipped: 0,
    };

    for (const row of retries.rows) {
      const user = await db.queryObject<{ name: string; mail: string | null }>(
        `SELECT name, mail FROM users WHERE id = $1;`,
        [row.user_id],
      );
      const name = user.rows[0]?.name ?? 'Jugador';
      let message: EmailMessage | null = null;
      if (row.template_key === 'welcome') {
        message = buildWelcomeEmail({ name, mail: row.recipient_email });
      } else if (row.template_key === 'streak_at_risk') {
        const streakCount = await findUserStreakCount(db, row.user_id);
        message = buildStreakAtRiskEmail(name, row.recipient_email, streakCount);
      } else if (row.template_key === 'streak_lost') {
        const streakCount = await findUserStreakCount(db, row.user_id);
        message = buildStreakLostEmail(name, row.recipient_email, streakCount);
      }
      if (!message) {
        stats.skipped += 1;
        continue;
      }
      const result = await deliverTrackedEmail({
        userId: row.user_id,
        templateKey: row.template_key,
        dedupeKey: row.dedupe_key,
        message,
        afterSent: row.template_key === 'welcome'
          ? (client) => markWelcomeEmailSent(client, row.user_id)
          : undefined,
      });
      if (result === 'sent') stats.sent += 1;
      else if (result === 'failed') stats.failed += 1;
      else stats.skipped += 1;
    }

    return { expiredPending, retry: stats };
  });
}

export async function runPendingWelcomeJob() {
  if (!isEmailDeliveryConfigured()) {
    return { skipped: true, reason: 'brevo_not_configured' };
  }
  const cfg = emailConfig();

  return withDb(async (db) => {
    const pending = await db.queryObject<{
      id: string;
      user_id: string;
      recipient_email: string;
    }>(
      `
        SELECT ed.id, ed.user_id, ed.recipient_email
        FROM email_deliveries ed
        INNER JOIN users u ON u.id = ed.user_id
        WHERE ed.status = 'pending'
          AND ed.template_key = 'welcome'
          AND u.mail_verified_at IS NOT NULL
        ORDER BY ed.created_at ASC
        LIMIT $1;
      `,
      [cfg.welcomeBatchLimit],
    );

    const stats: DeliveryBatchStats = {
      attempted: pending.rows.length,
      sent: 0,
      failed: 0,
      skipped: 0,
    };

    for (const row of pending.rows) {
      const user = await db.queryObject<{ name: string }>(
        `SELECT name FROM users WHERE id = $1;`,
        [row.user_id],
      );
      const name = user.rows[0]?.name ?? 'Jugador';
      const message = buildWelcomeEmail({ name, mail: row.recipient_email });
      const result = await deliverTrackedEmail({
        userId: row.user_id,
        templateKey: 'welcome',
        dedupeKey: 'welcome',
        message,
        afterSent: (client) => markWelcomeEmailSent(client, row.user_id),
      });
      if (result === 'sent') stats.sent += 1;
      else if (result === 'failed') stats.failed += 1;
      else stats.skipped += 1;
    }

    return { pendingWelcome: stats };
  });
}

export async function runLeaderboardRefreshJob(): Promise<unknown> {
  const results = await refreshAllLeaderboards();
  const failed = results.filter((row) => row.error);
  return {
    source: 'supabase-edge',
    scopes: results.length,
    failed: failed.length,
    results,
  };
}
