import { PoolClient } from 'pg';
import { query } from '../../config/database';
import {
  EmailDeliveryRow,
  EmailDeliveryStatus,
  EmailTemplateKey,
  FailedDeliveryRetryCandidate,
  ListEmailDeliveriesFilters,
  PendingWelcomeDelivery,
  StreakEmailCandidate,
  UserEmailContext,
  UserStreakContext
} from './email.types';

interface AcquireDeliveryInput {
  userId: string;
  templateKey: EmailTemplateKey;
  dedupeKey: string;
  recipientEmail: string;
  subject: string;
}

export async function isWelcomeEmailSkipped(userId: string): Promise<boolean> {
  const result = await query<{ skip: boolean }>(
    `
      SELECT (
        u.mail IS NULL
        OR u.welcome_email_sent_at IS NOT NULL
        OR EXISTS (
          SELECT 1
          FROM email_deliveries ed
          WHERE ed.user_id = u.id
            AND ed.template_key = 'welcome'
            AND ed.dedupe_key = 'welcome'
            AND ed.status = 'sent'
        )
      ) AS skip
      FROM users u
      WHERE u.id = $1;
    `,
    [userId]
  );

  return Boolean(result.rows[0]?.skip);
}

export async function expireStalePendingDeliveries(staleMinutes: number): Promise<number> {
  const safeMinutes = Math.max(1, staleMinutes);
  const result = await query(
    `
      UPDATE email_deliveries
      SET
        status = 'failed',
        error_message = 'Delivery timed out while pending',
        failed_at = now()
      WHERE status = 'pending'
        AND created_at < now() - ($1::text || ' minutes')::interval;
    `,
    [String(safeMinutes)]
  );

  return result.rowCount ?? 0;
}

export async function acquireDeliverySlot(
  client: PoolClient,
  input: AcquireDeliveryInput
): Promise<string | null> {
  const existing = await client.query<{ id: string; status: EmailDeliveryStatus }>(
    `
      SELECT id, status
      FROM email_deliveries
      WHERE user_id = $1
        AND template_key = $2
        AND dedupe_key = $3;
    `,
    [input.userId, input.templateKey, input.dedupeKey]
  );

  const row = existing.rows[0];
  if (row?.status === 'sent' || row?.status === 'pending') {
    return null;
  }

  if (row?.status === 'failed') {
    const retry = await client.query<{ id: string }>(
      `
        UPDATE email_deliveries
        SET
          status = 'pending',
          recipient_email = $2,
          subject = $3,
          provider_message_id = NULL,
          error_message = NULL,
          failed_at = NULL,
          sent_at = NULL,
          attempt_count = attempt_count + 1
        WHERE id = $1
        RETURNING id;
      `,
      [row.id, input.recipientEmail, input.subject]
    );
    return retry.rows[0]?.id ?? null;
  }

  const created = await client.query<{ id: string }>(
    `
      INSERT INTO email_deliveries (
        user_id,
        template_key,
        dedupe_key,
        recipient_email,
        subject,
        status
      )
      VALUES ($1, $2, $3, $4, $5, 'pending')
      RETURNING id;
    `,
    [
      input.userId,
      input.templateKey,
      input.dedupeKey,
      input.recipientEmail,
      input.subject
    ]
  );

  return created.rows[0]?.id ?? null;
}

export async function markDeliverySent(
  deliveryId: string,
  providerMessageId: string | null
): Promise<void> {
  await query(
    `
      UPDATE email_deliveries
      SET
        status = 'sent',
        provider_message_id = $2,
        error_message = NULL,
        failed_at = NULL,
        sent_at = now()
      WHERE id = $1;
    `,
    [deliveryId, providerMessageId]
  );
}

export async function markDeliveryFailed(
  deliveryId: string,
  errorMessage: string
): Promise<void> {
  await query(
    `
      UPDATE email_deliveries
      SET
        status = 'failed',
        error_message = $2,
        failed_at = now(),
        sent_at = NULL
      WHERE id = $1;
    `,
    [deliveryId, errorMessage.slice(0, 1000)]
  );
}

export async function markWelcomeEmailSent(
  client: PoolClient,
  userId: string
): Promise<void> {
  await client.query(
    `
      UPDATE users
      SET welcome_email_sent_at = now(), updated_at = now()
      WHERE id = $1 AND welcome_email_sent_at IS NULL;
    `,
    [userId]
  );
}

export async function listDeliveries(
  filters: ListEmailDeliveriesFilters = {}
): Promise<EmailDeliveryRow[]> {
  const conditions: string[] = [];
  const params: unknown[] = [];

  if (filters.userId) {
    params.push(filters.userId);
    conditions.push(`ed.user_id = $${params.length}`);
  }

  if (filters.templateKey) {
    params.push(filters.templateKey);
    conditions.push(`ed.template_key = $${params.length}`);
  }

  if (filters.status) {
    params.push(filters.status);
    conditions.push(`ed.status = $${params.length}`);
  }

  const limit = Math.min(Math.max(filters.limit ?? 50, 1), 200);
  params.push(limit);

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const result = await query<EmailDeliveryRow>(
    `
      SELECT
        ed.id,
        ed.user_id,
        u.username,
        u.mail AS user_mail,
        ed.template_key,
        ed.dedupe_key,
        ed.recipient_email,
        ed.subject,
        ed.status,
        ed.provider_message_id,
        ed.error_message,
        ed.attempt_count,
        ed.created_at,
        ed.sent_at,
        ed.failed_at
      FROM email_deliveries ed
      JOIN users u ON u.id = ed.user_id
      ${whereClause}
      ORDER BY ed.created_at DESC
      LIMIT $${params.length};
    `,
    params
  );

  return result.rows;
}

export async function findStreakAtRiskCandidates(today: string): Promise<StreakEmailCandidate[]> {
  const result = await query<StreakEmailCandidate>(
    `
      SELECT
        u.id AS "userId",
        u.mail AS mail,
        u.name AS name,
        s.id AS "streakId",
        s.current_count AS "currentCount",
        s.best_count AS "bestCount",
        to_char(s.last_activity_day, 'YYYY-MM-DD') AS "lastActivityDay"
      FROM users u
      JOIN profiles p ON p.user_id = u.id
      JOIN streaks s ON s.id = p.streak_id
      WHERE u.mail IS NOT NULL
        AND u.email_notifications_enabled = true
        AND s.current_count > 0
        AND s.last_activity_day = ($1::date - INTERVAL '1 day')::date
        AND NOT EXISTS (
          SELECT 1
          FROM email_deliveries ed
          WHERE ed.user_id = u.id
            AND ed.template_key = 'streak_at_risk'
            AND ed.dedupe_key = 'at_risk:' || $1
            AND ed.status IN ('sent', 'pending')
        );
    `,
    [today]
  );

  return result.rows;
}

export async function findStreakLostCandidates(today: string): Promise<StreakEmailCandidate[]> {
  const result = await query<StreakEmailCandidate>(
    `
      SELECT
        u.id AS "userId",
        u.mail AS mail,
        u.name AS name,
        s.id AS "streakId",
        s.current_count AS "currentCount",
        s.best_count AS "bestCount",
        to_char(s.last_activity_day, 'YYYY-MM-DD') AS "lastActivityDay"
      FROM users u
      JOIN profiles p ON p.user_id = u.id
      JOIN streaks s ON s.id = p.streak_id
      WHERE u.mail IS NOT NULL
        AND u.email_notifications_enabled = true
        AND s.current_count > 0
        AND s.last_activity_day <= ($1::date - INTERVAL '2 days')::date
        AND NOT EXISTS (
          SELECT 1
          FROM email_deliveries ed
          WHERE ed.user_id = u.id
            AND ed.template_key = 'streak_lost'
            AND ed.dedupe_key = 'lost:' || to_char(s.last_activity_day, 'YYYY-MM-DD')
            AND ed.status IN ('sent', 'pending')
        );
    `,
    [today]
  );

  return result.rows;
}

export async function resetExpiredStreak(client: PoolClient, streakId: string): Promise<void> {
  await client.query(
    `
      UPDATE streaks
      SET current_count = 0, updated_at = now()
      WHERE id = $1;
    `,
    [streakId]
  );
}

export async function reconcileExpiredStreaksInDatabase(today: string): Promise<number> {
  const result = await query(
    `
      UPDATE streaks s
      SET current_count = 0, updated_at = now()
      FROM profiles p
      WHERE p.streak_id = s.id
        AND s.current_count > 0
        AND s.last_activity_day <= ($1::date - INTERVAL '2 days')::date
      RETURNING s.id;
    `,
    [today]
  );

  return result.rowCount ?? 0;
}

export async function findPendingWelcomeDeliveries(
  limit: number
): Promise<PendingWelcomeDelivery[]> {
  const safeLimit = Math.max(1, Math.min(limit, 100));
  const result = await query<PendingWelcomeDelivery>(
    `
      SELECT
        ed.id,
        ed.user_id AS "userId",
        ed.recipient_email AS "recipientEmail"
      FROM email_deliveries ed
      WHERE ed.status = 'pending'
        AND ed.template_key = 'welcome'
        AND ed.recipient_email IS NOT NULL
      ORDER BY ed.created_at ASC
      LIMIT $1;
    `,
    [safeLimit]
  );

  return result.rows;
}

export async function findUserIdByMail(mail: string): Promise<string | null> {
  const result = await query<{ id: string }>(
    `
      SELECT id
      FROM users
      WHERE mail = $1;
    `,
    [mail]
  );

  return result.rows[0]?.id ?? null;
}

export async function disableEmailNotificationsByUserId(userId: string): Promise<void> {
  await query(
    `
      UPDATE users
      SET email_notifications_enabled = false, updated_at = now()
      WHERE id = $1;
    `,
    [userId]
  );
}

export async function findRetryableFailedDeliveries(input: {
  limit: number;
  maxAttempts: number;
  maxAgeHours: number;
}): Promise<FailedDeliveryRetryCandidate[]> {
  const safeLimit = Math.max(1, Math.min(input.limit, 200));
  const safeMaxAttempts = Math.max(1, input.maxAttempts);
  const safeMaxAgeHours = Math.max(1, input.maxAgeHours);

  const result = await query<FailedDeliveryRetryCandidate>(
    `
      SELECT
        id,
        user_id AS "userId",
        template_key AS "templateKey",
        dedupe_key AS "dedupeKey",
        recipient_email AS "recipientEmail",
        attempt_count AS "attemptCount"
      FROM email_deliveries ed
      WHERE status = 'failed'
        AND recipient_email IS NOT NULL
        AND attempt_count < $1
        AND failed_at >= now() - ($2::text || ' hours')::interval
        AND (
          ed.template_key = 'welcome'
          OR EXISTS (
            SELECT 1
            FROM users u
            WHERE u.id = ed.user_id
              AND u.email_notifications_enabled = true
          )
        )
      ORDER BY failed_at ASC
      LIMIT $3;
    `,
    [safeMaxAttempts, String(safeMaxAgeHours), safeLimit]
  );

  return result.rows;
}

export async function findUserEmailContext(
  userId: string
): Promise<UserEmailContext | null> {
  const result = await query<UserEmailContext>(
    `
      SELECT id AS "userId", name, mail
      FROM users
      WHERE id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function findUserStreakContext(
  userId: string
): Promise<UserStreakContext | null> {
  const result = await query<UserStreakContext>(
    `
      SELECT
        s.id AS "streakId",
        s.current_count AS "currentCount"
      FROM profiles p
      JOIN streaks s ON s.id = p.streak_id
      WHERE p.user_id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}
