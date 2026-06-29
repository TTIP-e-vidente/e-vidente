import { withDb } from '../db.ts';
import { isDevelopmentEnvironment, isEmailDeliveryConfigured } from '../brevo.ts';
import * as userRepository from '../repositories/user.ts';
import {
  getVerificationConfig,
  getVerificationCooldownRemainingSeconds,
} from '../verification.ts';

interface DeliveryRow {
  status: 'pending' | 'sent' | 'failed';
  sent_at: Date | null;
  failed_at: Date | null;
  error_message: string | null;
}

interface ActiveCodeRow {
  target_mail: string;
  expires_at: Date;
  failed_attempt_count: number;
}

export async function getEmailVerificationStatus(userId: string) {
  const user = await userRepository.findPublicUserById(userId);
  if (!user) return null;

  const deliveryConfigured = isEmailDeliveryConfigured();
  const config = getVerificationConfig();
  const cooldownSeconds = await getVerificationCooldownRemainingSeconds(userId);
  const trimmedMail = user.mail?.trim() ?? '';
  const mailVerified = user.mail_verified_at != null;
  const required = trimmedMail.length > 0 && !mailVerified;

  const { active, lastDelivery } = await withDb(async (db) => {
    const activeResult = await db.queryObject<ActiveCodeRow>(
      `
        SELECT target_mail, expires_at, failed_attempt_count
        FROM email_verification_codes
        WHERE user_id = $1
          AND used_at IS NULL
          AND expires_at > now()
        ORDER BY created_at DESC
        LIMIT 1;
      `,
      [userId],
    );
    const deliveryResult = await db.queryObject<DeliveryRow>(
      `
        SELECT status, sent_at, failed_at, error_message
        FROM email_deliveries
        WHERE user_id = $1 AND template_key = 'email_verification'
        ORDER BY created_at DESC
        LIMIT 1;
      `,
      [userId],
    );
    return {
      active: activeResult.rows[0] ?? null,
      lastDelivery: deliveryResult.rows[0] ?? null,
    };
  });

  let attemptsRemaining: number | null = null;
  if (active && active.expires_at >= new Date()) {
    attemptsRemaining = Math.max(0, config.maxAttempts - active.failed_attempt_count);
  }

  return {
    mail: trimmedMail || null,
    mail_verified_at: user.mail_verified_at ? user.mail_verified_at.toISOString() : null,
    email_notifications_enabled: user.email_notifications_enabled,
    delivery_configured: deliveryConfigured,
    dev_code_in_logs: isDevelopmentEnvironment() && !deliveryConfigured,
    last_verification_delivery: lastDelivery
      ? {
        status: lastDelivery.status,
        sent_at: lastDelivery.sent_at ? lastDelivery.sent_at.toISOString() : null,
        failed_at: lastDelivery.failed_at ? lastDelivery.failed_at.toISOString() : null,
        error_message: lastDelivery.error_message,
      }
      : null,
    verification: {
      required,
      has_pending_code: active != null && active.expires_at >= new Date(),
      pending_target_mail: active?.target_mail ?? null,
      expires_at: active ? active.expires_at.toISOString() : null,
      cooldown_seconds: cooldownSeconds,
      max_attempts: config.maxAttempts,
      attempts_remaining: attemptsRemaining,
    },
  };
}
