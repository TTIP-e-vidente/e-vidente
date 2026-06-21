import * as emailRepository from './email.repository';

const HARD_BOUNCE_EVENTS = new Set([
  'hard_bounce',
  'invalid_email',
  'blocked',
  'unsubscribed'
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

function buildFailureMessage(eventName: string, reason: string): string {
  if (reason) {
    return `Brevo ${eventName}: ${reason}`.slice(0, 1000);
  }
  return `Brevo ${eventName}`.slice(0, 1000);
}

export async function handleBrevoWebhookEvents(
  events: BrevoWebhookEvent[]
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

    if (providerMessageId && (HARD_BOUNCE_EVENTS.has(eventName) || SOFT_BOUNCE_EVENTS.has(eventName))) {
      const updated = await emailRepository.markDeliveryFailedByProviderMessageId(
        providerMessageId,
        buildFailureMessage(eventName, reason)
      );
      deliveriesUpdated += updated;
    }

    if (!email || !HARD_BOUNCE_EVENTS.has(eventName)) {
      continue;
    }

    const userId = await emailRepository.findUserIdByMail(email);
    if (userId) {
      await emailRepository.disableEmailNotificationsByUserId(userId);
      suppressed += 1;
      console.warn(`[email] webhook suppressed notifications for ${email} (${eventName})`);
    }
  }

  return { processed, suppressed, deliveries_updated: deliveriesUpdated };
}
