import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';
import { sendTransactionalEmail, type EmailMessage } from './brevo.ts';
import { withDb, withTransaction } from './db.ts';

export type DeliveryBatchStats = {
  attempted: number;
  sent: number;
  failed: number;
  skipped: number;
};

export async function acquireDeliverySlot(
  db: Client,
  input: {
    userId: string;
    templateKey: string;
    dedupeKey: string;
    recipientEmail: string;
    subject: string;
  },
): Promise<string | null> {
  const existing = await db.queryObject<{ id: string; status: string }>(
    `
      SELECT id, status
      FROM email_deliveries
      WHERE user_id = $1 AND template_key = $2 AND dedupe_key = $3;
    `,
    [input.userId, input.templateKey, input.dedupeKey],
  );
  const row = existing.rows[0];
  if (row?.status === 'sent' || row?.status === 'pending') {
    return null;
  }
  if (row?.status === 'failed') {
    const retry = await db.queryObject<{ id: string }>(
      `
        UPDATE email_deliveries
        SET status = 'pending', recipient_email = $2, subject = $3,
            provider_message_id = NULL, error_message = NULL,
            failed_at = NULL, sent_at = NULL, attempt_count = attempt_count + 1
        WHERE id = $1
        RETURNING id;
      `,
      [row.id, input.recipientEmail, input.subject],
    );
    return retry.rows[0]?.id ?? null;
  }
  const created = await db.queryObject<{ id: string }>(
    `
      INSERT INTO email_deliveries (
        user_id, template_key, dedupe_key, recipient_email, subject, status
      ) VALUES ($1, $2, $3, $4, $5, 'pending')
      RETURNING id;
    `,
    [
      input.userId,
      input.templateKey,
      input.dedupeKey,
      input.recipientEmail,
      input.subject,
    ],
  );
  return created.rows[0]?.id ?? null;
}

async function markDeliverySent(
  db: Client,
  deliveryId: string,
  providerMessageId: string | null,
): Promise<void> {
  await db.queryObject(
    `
      UPDATE email_deliveries
      SET status = 'sent', sent_at = now(), provider_message_id = $2, error_message = NULL
      WHERE id = $1;
    `,
    [deliveryId, providerMessageId],
  );
}

async function markDeliveryFailed(
  db: Client,
  deliveryId: string,
  errorMessage: string,
): Promise<void> {
  await db.queryObject(
    `
      UPDATE email_deliveries
      SET status = 'failed', error_message = $2, failed_at = now(), sent_at = NULL
      WHERE id = $1;
    `,
    [deliveryId, errorMessage.slice(0, 1000)],
  );
}

export async function deliverTrackedEmail(input: {
  userId: string;
  templateKey: string;
  dedupeKey: string;
  message: EmailMessage;
  afterSent?: (db: Client) => Promise<void>;
}): Promise<'sent' | 'skipped' | 'failed'> {
  let deliveryId: string | null = null;
  await withTransaction(async (db) => {
    deliveryId = await acquireDeliverySlot(db, {
      userId: input.userId,
      templateKey: input.templateKey,
      dedupeKey: input.dedupeKey,
      recipientEmail: input.message.to,
      subject: input.message.subject,
    });
  });

  if (!deliveryId) {
    return 'skipped';
  }

  try {
    const providerMessageId = await sendTransactionalEmail(
      input.message,
      input.templateKey,
    );
    await withTransaction(async (db) => {
      await markDeliverySent(db, deliveryId!, providerMessageId);
      if (input.afterSent) {
        await input.afterSent(db);
      }
    });
    return 'sent';
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    await withDb(async (db) => markDeliveryFailed(db, deliveryId!, msg));
    return 'failed';
  }
}

export function getTodayInTimezone(timezone: string, reference = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(reference);
}

export async function expireStalePendingDeliveries(
  db: Client,
  staleMinutes: number,
): Promise<number> {
  const safeMinutes = Math.max(1, staleMinutes);
  const result = await db.queryObject(
    `
      UPDATE email_deliveries
      SET status = 'failed',
          error_message = 'Delivery timed out while pending',
          failed_at = now()
      WHERE status = 'pending'
        AND created_at < now() - ($1::text || ' minutes')::interval;
    `,
    [String(safeMinutes)],
  );
  return result.rowCount ?? 0;
}

export async function markWelcomeEmailSent(db: Client, userId: string): Promise<void> {
  await db.queryObject(
    `
      UPDATE users
      SET welcome_email_sent_at = now(), updated_at = now()
      WHERE id = $1;
    `,
    [userId],
  );
}
