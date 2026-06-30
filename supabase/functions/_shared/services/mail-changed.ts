import { isEmailDeliveryConfigured } from '../brevo.ts';
import { deliverTrackedEmail } from '../delivery.ts';
import { buildMailChangedEmail } from '../email/build-messages.ts';

export async function sendMailChangedEmail(input: {
  userId: string;
  name: string;
  oldMail: string;
  newMail: string;
}): Promise<void> {
  const oldMail = input.oldMail.trim();
  const newMail = input.newMail.trim();
  if (!oldMail || !newMail || !isEmailDeliveryConfigured()) {
    return;
  }

  const message = buildMailChangedEmail({
    name: input.name,
    oldMail,
    newMail,
  });

  try {
    await deliverTrackedEmail({
      userId: input.userId,
      templateKey: 'mail_changed',
      dedupeKey: `mail_changed:${newMail.toLowerCase()}`,
      message,
    });
  } catch (error) {
    console.warn(
      '[mail-changed] send failed',
      input.userId,
      error instanceof Error ? error.message : String(error),
    );
  }
}
