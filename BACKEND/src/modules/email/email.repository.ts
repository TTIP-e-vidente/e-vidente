import { PoolClient, QueryResult } from 'pg';
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
  deliveryIdOrClient: string | PoolClient,
  deliveryIdOrMessageId: string,
  providerMessageIdArg?: string | null
): Promise<void> {
  // Overloads:
  //   markDeliverySent(deliveryId, providerMessageId)           — pool global
  //   markDeliverySent(client, deliveryId, providerMessageId)   — transaccional
  let executor: (sql: string, params: unknown[]) => Promise<QueryResult>;
  let deliveryId: string;
  let providerMessageId: string | null;

  if (typeof deliveryIdOrClient === 'string') {
    // Pool global (backward compatible)
    executor = (sql, params) => query(sql, params);
    deliveryId = deliveryIdOrClient;
    providerMessageId = deliveryIdOrMessageId as string | null;
  } else {
    // Transaccional: usa el PoolClient proporcionado
    executor = (sql, params) => (deliveryIdOrClient as PoolClient).query(sql, params);
    deliveryId = deliveryIdOrMessageId;
    providerMessageId = providerMessageIdArg ?? null;
  }

  await executor(
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

export interface LatestEmailDeliverySnapshot {
  status: EmailDeliveryStatus;
  sent_at: Date | null;
  failed_at: Date | null;
  error_message: string | null;
  created_at: Date;
}

export async function findLatestDeliveryForUser(
  userId: string,
  templateKey: EmailTemplateKey
): Promise<LatestEmailDeliverySnapshot | null> {
  const result = await query<LatestEmailDeliverySnapshot>(
    `
      SELECT status, sent_at, failed_at, error_message, created_at
      FROM email_deliveries
      WHERE user_id = $1
        AND template_key = $2
      ORDER BY created_at DESC
      LIMIT 1;
    `,
    [userId, templateKey]
  );

  return result.rows[0] ?? null;
}

function normalizeProviderMessageId(providerMessageId: string): string {
  return providerMessageId.replace(/^<|>$/g, '').trim();
}

export async function markDeliveryFailedByProviderMessageId(
  providerMessageId: string,
  errorMessage: string
): Promise<number> {
  const normalized = normalizeProviderMessageId(providerMessageId);
  if (!normalized) {
    return 0;
  }

  const result = await query(
    `
      UPDATE email_deliveries
      SET
        status = 'failed',
        error_message = $2,
        failed_at = now(),
        sent_at = NULL
      WHERE provider_message_id = $1
         OR provider_message_id = $3
         OR provider_message_id = $4;
    `,
    [normalized, errorMessage.slice(0, 1000), `<${normalized}>`, providerMessageId.trim()]
  );

  return result.rowCount ?? 0;
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

export interface EmailDeliverySummary {
  pending: number;
  sent: number;
  failed: number;
  total: number;
}

export async function summarizeDeliveries(filters: {
  userId?: string;
  templateKey?: EmailTemplateKey;
} = {}): Promise<EmailDeliverySummary> {
  const conditions: string[] = [];
  const params: unknown[] = [];

  if (filters.userId) {
    params.push(filters.userId);
    conditions.push(`user_id = $${params.length}`);
  }

  if (filters.templateKey) {
    params.push(filters.templateKey);
    conditions.push(`template_key = $${params.length}`);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const result = await query<{ status: EmailDeliveryStatus; count: string }>(
    `
      SELECT status, COUNT(*)::text AS count
      FROM email_deliveries
      ${whereClause}
      GROUP BY status;
    `,
    params
  );

  const summary: EmailDeliverySummary = {
    pending: 0,
    sent: 0,
    failed: 0,
    total: 0
  };

  for (const row of result.rows) {
    const count = Number.parseInt(row.count, 10);
    summary[row.status] = count;
    summary.total += count;
  }

  return summary;
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
        AND u.mail_verified_at IS NOT NULL
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
        AND u.mail_verified_at IS NOT NULL
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

export async function isUserMailVerified(userId: string): Promise<boolean> {
  const result = await query<{ verified: boolean }>(
    `
      SELECT (mail_verified_at IS NOT NULL) AS verified
      FROM users
      WHERE id = $1;
    `,
    [userId]
  );
  return Boolean(result.rows[0]?.verified);
}

export async function cancelPendingWelcomeForUnverifiedUsers(): Promise<number> {
  const result = await query(
    `
      UPDATE email_deliveries ed
      SET
        status = 'failed',
        error_message = 'Cancelled: user mail not verified',
        failed_at = now()
      FROM users u
      WHERE ed.user_id = u.id
        AND ed.template_key = 'welcome'
        AND ed.status = 'pending'
        AND u.mail_verified_at IS NULL;
    `
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
      INNER JOIN users u ON u.id = ed.user_id
      WHERE ed.status = 'pending'
        AND ed.template_key = 'welcome'
        AND ed.recipient_email IS NOT NULL
        AND u.mail_verified_at IS NOT NULL
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
          OR ed.template_key = 'mail_changed'
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

// ─── Verificación de email ────────────────────────────────────────────────────

export interface EmailVerificationCodeRow {
  id: string;
  userId: string;
  codeHash: string;
  targetMail: string;
  expiresAt: Date;
  usedAt: Date | null;
  createdAt: Date;
  failedAttemptCount: number;
}

export async function createVerificationCode(
  client: PoolClient,
  input: {
    userId: string;
    codeHash: string;
    targetMail: string;
    expiresAt: Date;
  }
): Promise<string> {
  const result = await client.query<{ id: string }>(
    `
      INSERT INTO email_verification_codes (user_id, code_hash, target_mail, expires_at)
      VALUES ($1, $2, $3, $4)
      RETURNING id;
    `,
    [input.userId, input.codeHash, input.targetMail, input.expiresAt]
  );
  return result.rows[0].id;
}

export async function findActiveVerificationCode(
  userId: string
): Promise<EmailVerificationCodeRow | null> {
  const result = await query<{
    id: string;
    user_id: string;
    code_hash: string;
    target_mail: string;
    expires_at: Date;
    used_at: Date | null;
    created_at: Date;
    failed_attempt_count: number;
  }>(
    `
      SELECT id, user_id, code_hash, target_mail, expires_at, used_at, created_at, failed_attempt_count
      FROM email_verification_codes
      WHERE user_id = $1
        AND used_at IS NULL
        AND expires_at > now()
      ORDER BY created_at DESC
      LIMIT 1;
    `,
    [userId]
  );

  const row = result.rows[0];
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    codeHash: row.code_hash,
    targetMail: row.target_mail,
    expiresAt: row.expires_at,
    usedAt: row.used_at,
    createdAt: row.created_at,
    failedAttemptCount: row.failed_attempt_count
  };
}

export async function getLastVerificationCodeCreatedAt(
  userId: string
): Promise<Date | null> {
  const result = await query<{ created_at: Date }>(
    `
      SELECT created_at
      FROM email_verification_codes
      WHERE user_id = $1
        AND used_at IS NULL
        AND expires_at > now()
      ORDER BY created_at DESC
      LIMIT 1;
    `,
    [userId]
  );
  return result.rows[0]?.created_at ?? null;
}

export async function invalidatePreviousVerificationCodes(
  client: PoolClient,
  userId: string
): Promise<void> {
  await client.query(
    `
      UPDATE email_verification_codes
      SET used_at = now()
      WHERE user_id = $1
        AND used_at IS NULL;
    `,
    [userId]
  );
}

export async function markVerificationCodeUsed(
  client: PoolClient,
  codeId: string
): Promise<void> {
  await client.query(
    `
      UPDATE email_verification_codes
      SET used_at = now()
      WHERE id = $1;
    `,
    [codeId]
  );
}

export async function markMailVerified(
  client: PoolClient,
  userId: string,
  mail: string
): Promise<boolean> {
  const normalizedMail = mail.trim().toLowerCase();
  const result = await client.query(
    `
      UPDATE users
      SET mail_verified_at = now(), updated_at = now()
      WHERE id = $1
        AND mail_verified_at IS NULL
        AND lower(trim(coalesce(mail, ''))) = $2
      RETURNING id;
    `,
    [userId, normalizedMail]
  );
  return (result.rowCount ?? 0) > 0;
}

export async function incrementVerificationFailedAttempts(codeId: string): Promise<number> {
  const result = await query<{ failed_attempt_count: number }>(
    `
      UPDATE email_verification_codes
      SET failed_attempt_count = failed_attempt_count + 1
      WHERE id = $1
      RETURNING failed_attempt_count;
    `,
    [codeId]
  );
  return result.rows[0]?.failed_attempt_count ?? 0;
}
