import * as emailRepository from './email.repository';

const HARD_BOUNCE_EVENTS = new Set([
  'hard_bounce',
  'invalid_email',
  'blocked',
  'unsubscribed'
]);

export interface BrevoWebhookEvent {
  event?: unknown;
  email?: unknown;
  'message-id'?: unknown;
  messageId?: unknown;
}

function asTrimmedString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

export async function handleBrevoWebhookEvents(
  events: BrevoWebhookEvent[]
): Promise<{ processed: number; suppressed: number }> {
  let processed = 0;
  let suppressed = 0;

  for (const event of events) {
    const eventName = asTrimmedString(event.event).toLowerCase();
    const email = asTrimmedString(event.email).toLowerCase();
    if (!eventName || !email) {
      continue;
    }

    processed += 1;

    if (!HARD_BOUNCE_EVENTS.has(eventName)) {
      continue;
    }

    const userId = await emailRepository.findUserIdByMail(email);
    if (userId) {
      await emailRepository.disableEmailNotificationsByUserId(userId);
      suppressed += 1;
      console.warn(`[email] webhook suppressed notifications for ${email} (${eventName})`);
    }
  }

  return { processed, suppressed };
}
