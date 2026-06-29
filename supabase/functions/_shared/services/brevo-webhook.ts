import { withDb } from '../db.ts';

const HARD_BOUNCE_EVENTS = new Set([
  'hard_bounce',
  'invalid_email',
  'blocked',
  'unsubscribed',
]);

const SOFT_BOUNCE_EVENTS = new Set(['soft_bounce', 'deferred']);

export interface BrevoWebhookEvent {
  event?: unknown;
  email?: unknown;
  'message-id'?: unknown;
  messageId?: unknown;
  reason?: unknown;
}

function asTrimmedString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function extractProviderMessageId(event: BrevoWebhookEvent): string {
  return asTrimmedString(event['message-id']) || asTrimmedString(event.messageId);
}

function normalizeProviderMessageId(providerMessageId: string): string {
  return providerMessageId.replace(/^<|>$/g, '').trim();
}

function buildFailureMessage(eventName: string, reason: string): string {
  if (reason) {
    return `Brevo ${eventName}: ${reason}`.slice(0, 1000);
  }
  return `Brevo ${eventName}`.slice(0, 1000);
}

async function markDeliveryFailedByProviderMessageId(
  providerMessageId: string,
  errorMessage: string,
): Promise<number> {
  const normalized = normalizeProviderMessageId(providerMessageId);
  if (!normalized) {
    return 0;
  }

  return withDb(async (db) => {
    const result = await db.queryObject(
      `
        UPDATE email_deliveries
        SET status = 'failed', error_message = $2, failed_at = now(), sent_at = NULL
        WHERE provider_message_id = $1
           OR provider_message_id = $3
           OR provider_message_id = $4;
      `,
      [normalized, errorMessage, `<${normalized}>`, providerMessageId.trim()],
    );
    return result.rowCount ?? 0;
  });
}

async function disableEmailNotificationsByMail(mail: string): Promise<boolean> {
  return withDb(async (db) => {
    const user = await db.queryObject<{ id: string }>(
      `
        SELECT id
        FROM users
        WHERE lower(trim(mail)) = lower(trim($1))
        LIMIT 1;
      `,
      [mail],
    );
    const userId = user.rows[0]?.id;
    if (!userId) {
      return false;
    }
    await db.queryObject(
      `
        UPDATE users
        SET email_notifications_enabled = false, updated_at = now()
        WHERE id = $1;
      `,
      [userId],
    );
    return true;
  });
}

export async function handleBrevoWebhookEvents(
  events: BrevoWebhookEvent[],
): Promise<{ processed: number; suppressed: number; deliveries_updated: number }> {
  let processed = 0;
  let suppressed = 0;
  let deliveriesUpdated = 0;

  for (const event of events) {
    const eventName = asTrimmedString(event.event).toLowerCase();
    const email = asTrimmedString(event.email).toLowerCase();
    const providerMessageId = extractProviderMessageId(event);
    const reason = asTrimmedString(event.reason);

    if (!eventName) {
      continue;
    }

    processed += 1;

    if (
      providerMessageId &&
      (HARD_BOUNCE_EVENTS.has(eventName) || SOFT_BOUNCE_EVENTS.has(eventName))
    ) {
      deliveriesUpdated += await markDeliveryFailedByProviderMessageId(
        providerMessageId,
        buildFailureMessage(eventName, reason),
      );
    }

    if (!email || !HARD_BOUNCE_EVENTS.has(eventName)) {
      continue;
    }

    if (await disableEmailNotificationsByMail(email)) {
      suppressed += 1;
      console.warn(`[brevo-webhook] suppressed notifications for ${email} (${eventName})`);
    }
  }

  return { processed, suppressed, deliveries_updated: deliveriesUpdated };
}
