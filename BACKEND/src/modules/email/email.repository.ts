import { PoolClient } from 'pg';
import { query } from '../../config/database';
import {
  EmailDeliveryRow,
  EmailDeliveryStatus,
  EmailTemplateKey,
  ListEmailDeliveriesFilters,
  StreakEmailCandidate
} from './email.types';

interface AcquireDeliveryInput {
  userId: string;
  templateKey: EmailTemplateKey;
  dedupeKey: string;
  recipientEmail: string;
  subject: string;
}

export async function hasSuccessfulDelivery(
  userId: string,
  templateKey: EmailTemplateKey,
  dedupeKey: string
): Promise<boolean> {
  const result = await query<{ exists: boolean }>(
    `
      SELECT EXISTS (
        SELECT 1
        FROM email_deliveries
        WHERE user_id = $1
          AND template_key = $2
          AND dedupe_key = $3
          AND status = 'sent'
      ) AS exists;
    `,
    [userId, templateKey, dedupeKey]
  );

  return Boolean(result.rows[0]?.exists);
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

export async function findWelcomeEmailCandidate(
  userId: string
): Promise<{ id: string; mail: string; name: string; welcome_email_sent_at: Date | null } | null> {
  const result = await query<{
    id: string;
    mail: string;
    name: string;
    welcome_email_sent_at: Date | null;
  }>(
    `
      SELECT id, mail, name, welcome_email_sent_at
      FROM users
      WHERE id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
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
        AND s.last_activity_day = ($1::date - INTERVAL '1 day')::date;
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
        AND s.last_activity_day <= ($1::date - INTERVAL '2 days')::date;
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
