import { PoolClient } from 'pg';
import { pool } from '../../config/database';
import { emailConfig, isEmailDeliveryConfigured } from './email.config';
import { sendTransactionalEmail } from './email.client';
import {
  buildEmailMessage,
  listEmailTemplateMetadata,
  previewEmailTemplate
} from './templates';
import { EmailTemplatePreviewParams } from './templates/types';
import * as emailRepository from './email.repository';
import {
  EmailDeliveryStatus,
  EmailMessage,
  EmailRecipient,
  EmailTemplateKey,
  ListEmailDeliveriesFilters
} from './email.types';

function logEmailFailure(context: string, error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  console.warn(`[email] ${context}: ${message}`);
}

function formatDeliveryError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function getPendingStaleMinutes(): number {
  const configured = emailConfig.pendingStaleMinutes;
  if (Number.isNaN(configured) || configured <= 0) {
    return 15;
  }
  return configured;
}

export async function cleanupStalePendingDeliveries(): Promise<number> {
  const expiredCount = await emailRepository.expireStalePendingDeliveries(
    getPendingStaleMinutes()
  );
  if (expiredCount > 0) {
    console.warn(`[email] expired ${expiredCount} stale pending deliveries`);
  }
  return expiredCount;
}

async function deliverTrackedEmail(input: {
  userId: string;
  templateKey: EmailTemplateKey;
  dedupeKey: string;
  message: EmailMessage;
  afterSent?: (client: PoolClient) => Promise<void>;
}): Promise<'sent' | 'skipped' | 'failed'> {
  const client = await pool.connect();
  let deliveryId: string | null = null;

  try {
    await client.query('BEGIN');
    deliveryId = await emailRepository.acquireDeliverySlot(client, {
      userId: input.userId,
      templateKey: input.templateKey,
      dedupeKey: input.dedupeKey,
      recipientEmail: input.message.to,
      subject: input.message.subject
    });
    if (!deliveryId) {
      await client.query('ROLLBACK');
      return 'skipped';
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  try {
    const providerMessageId = await sendTransactionalEmail(input.message);

    const postClient = await pool.connect();
    try {
      await postClient.query('BEGIN');
      await emailRepository.markDeliverySent(deliveryId, providerMessageId);
      if (input.afterSent) {
        await input.afterSent(postClient);
      }
      await postClient.query('COMMIT');
    } catch (error) {
      await postClient.query('ROLLBACK');
      throw error;
    } finally {
      postClient.release();
    }

    return 'sent';
  } catch (error) {
    await emailRepository.markDeliveryFailed(deliveryId, formatDeliveryError(error));
    throw error;
  }
}

async function shouldSkipWelcomeEmail(userId: string): Promise<boolean> {
  const user = await emailRepository.findWelcomeEmailCandidate(userId);
  if (!user?.mail) {
    return true;
  }
  if (user.welcome_email_sent_at !== null) {
    return true;
  }
  return emailRepository.hasSuccessfulDelivery(userId, 'welcome', 'welcome');
}

export async function sendWelcomeEmail(recipient: EmailRecipient): Promise<void> {
  if (!recipient.mail) {
    return;
  }
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] welcome skipped: EMAIL_ENABLED=false or missing Brevo config');
    return;
  }
  if (await shouldSkipWelcomeEmail(recipient.userId)) {
    return;
  }

  await cleanupStalePendingDeliveries();
  const message = buildEmailMessage('welcome', {
    name: recipient.name,
    mail: recipient.mail
  });

  await deliverTrackedEmail({
    userId: recipient.userId,
    templateKey: 'welcome',
    dedupeKey: 'welcome',
    message,
    afterSent: async (client) => {
      await emailRepository.markWelcomeEmailSent(client, recipient.userId);
    }
  });
}

export function queueWelcomeEmail(recipient: EmailRecipient): void {
  void sendWelcomeEmail(recipient).catch((error) => {
    logEmailFailure(`welcome failed for user ${recipient.userId}`, error);
  });
}

export async function sendStreakAtRiskEmailsForDate(today: string): Promise<{
  attempted: number;
  sent: number;
  failed: number;
  skipped: number;
}> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] streak_at_risk skipped: EMAIL_ENABLED=false or missing Brevo config');
    return { attempted: 0, sent: 0, failed: 0, skipped: 0 };
  }

  await cleanupStalePendingDeliveries();
  const candidates = await emailRepository.findStreakAtRiskCandidates(today);
  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (const candidate of candidates) {
    const dedupeKey = `at_risk:${today}`;
    const message = buildEmailMessage('streak_at_risk', {
      name: candidate.name,
      mail: candidate.mail,
      streakCount: candidate.currentCount
    });

    try {
      const result = await deliverTrackedEmail({
        userId: candidate.userId,
        templateKey: 'streak_at_risk',
        dedupeKey,
        message
      });
      if (result === 'sent') {
        sent += 1;
      } else {
        skipped += 1;
      }
    } catch (error) {
      failed += 1;
      logEmailFailure(`streak_at_risk failed for user ${candidate.userId}`, error);
    }
  }

  return { attempted: candidates.length, sent, failed, skipped };
}

export async function sendStreakLostEmailsForDate(today: string): Promise<{
  attempted: number;
  sent: number;
  failed: number;
  skipped: number;
  resetCount: number;
}> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] streak_lost skipped: EMAIL_ENABLED=false or missing Brevo config');
    return { attempted: 0, sent: 0, failed: 0, skipped: 0, resetCount: 0 };
  }

  await cleanupStalePendingDeliveries();
  const candidates = await emailRepository.findStreakLostCandidates(today);
  let sent = 0;
  let failed = 0;
  let skipped = 0;
  let resetCount = 0;

  for (const candidate of candidates) {
    const dedupeKey = `lost:${candidate.lastActivityDay}`;
    const message = buildEmailMessage('streak_lost', {
      name: candidate.name,
      mail: candidate.mail,
      streakCount: candidate.currentCount
    });

    try {
      const result = await deliverTrackedEmail({
        userId: candidate.userId,
        templateKey: 'streak_lost',
        dedupeKey,
        message,
        afterSent: async (client) => {
          await emailRepository.resetExpiredStreak(client, candidate.streakId);
          resetCount += 1;
        }
      });
      if (result === 'sent') {
        sent += 1;
      } else {
        skipped += 1;
      }
    } catch (error) {
      failed += 1;
      logEmailFailure(`streak_lost failed for user ${candidate.userId}`, error);
    }
  }

  return { attempted: candidates.length, sent, failed, skipped, resetCount };
}

export async function runStreakEmailJob(referenceDate?: string): Promise<{
  today: string;
  expiredPending: number;
  atRisk: { attempted: number; sent: number; failed: number; skipped: number };
  lost: { attempted: number; sent: number; failed: number; skipped: number; resetCount: number };
}> {
  const expiredPending = await cleanupStalePendingDeliveries();
  const today = referenceDate ?? getTodayInConfiguredTimezone();
  const atRisk = await sendStreakAtRiskEmailsForDate(today);
  const lost = await sendStreakLostEmailsForDate(today);
  return { today, expiredPending, atRisk, lost };
}

export function getTodayInConfiguredTimezone(reference = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: emailConfig.timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(reference);
}

export async function listEmailDeliveries(filters: ListEmailDeliveriesFilters = {}) {
  return emailRepository.listDeliveries(filters);
}

export function listEmailTemplates() {
  return listEmailTemplateMetadata();
}

export function buildTemplatePreview(
  templateKey: EmailTemplateKey,
  params: EmailTemplatePreviewParams = {}
) {
  return previewEmailTemplate(templateKey, params);
}

export function parseDeliveryStatus(value: unknown): EmailDeliveryStatus | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'pending' || normalized === 'sent' || normalized === 'failed') {
    return normalized;
  }
  return undefined;
}

export function parseTemplateKey(value: unknown): EmailTemplateKey | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  const normalized = value.trim().toLowerCase();
  if (normalized === 'welcome' || normalized === 'streak_at_risk' || normalized === 'streak_lost') {
    return normalized;
  }
  return undefined;
}
