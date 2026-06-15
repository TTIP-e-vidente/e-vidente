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
  FailedDeliveryRetryCandidate,
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

async function mapWithConcurrency<T>(
  items: T[],
  concurrency: number,
  worker: (item: T) => Promise<void>
): Promise<void> {
  if (items.length === 0) {
    return;
  }

  const safeConcurrency = Math.max(1, Math.min(concurrency, items.length));
  let nextIndex = 0;

  async function runWorker(): Promise<void> {
    while (true) {
      const currentIndex = nextIndex;
      nextIndex += 1;
      if (currentIndex >= items.length) {
        return;
      }
      await worker(items[currentIndex]);
    }
  }

  await Promise.all(Array.from({ length: safeConcurrency }, () => runWorker()));
}

type DeliveryBatchStats = {
  attempted: number;
  sent: number;
  failed: number;
  skipped: number;
};

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
  return emailRepository.isWelcomeEmailSkipped(userId);
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

export async function sendStreakAtRiskEmailsForDate(
  today: string,
  options: { cleanupStale?: boolean } = {}
): Promise<DeliveryBatchStats> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] streak_at_risk skipped: EMAIL_ENABLED=false or missing Brevo config');
    return { attempted: 0, sent: 0, failed: 0, skipped: 0 };
  }

  if (options.cleanupStale ?? true) {
    await cleanupStalePendingDeliveries();
  }

  const candidates = await emailRepository.findStreakAtRiskCandidates(today);
  const stats: DeliveryBatchStats = {
    attempted: candidates.length,
    sent: 0,
    failed: 0,
    skipped: 0
  };

  await mapWithConcurrency(candidates, emailConfig.batchConcurrency, async (candidate) => {
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
        stats.sent += 1;
      } else {
        stats.skipped += 1;
      }
    } catch (error) {
      stats.failed += 1;
      logEmailFailure(`streak_at_risk failed for user ${candidate.userId}`, error);
    }
  });

  return stats;
}

export async function sendStreakLostEmailsForDate(
  today: string,
  options: { cleanupStale?: boolean } = {}
): Promise<DeliveryBatchStats & { resetCount: number }> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] streak_lost skipped: EMAIL_ENABLED=false or missing Brevo config');
    return { attempted: 0, sent: 0, failed: 0, skipped: 0, resetCount: 0 };
  }

  if (options.cleanupStale ?? true) {
    await cleanupStalePendingDeliveries();
  }

  const candidates = await emailRepository.findStreakLostCandidates(today);
  const stats: DeliveryBatchStats & { resetCount: number } = {
    attempted: candidates.length,
    sent: 0,
    failed: 0,
    skipped: 0,
    resetCount: 0
  };

  await mapWithConcurrency(candidates, emailConfig.batchConcurrency, async (candidate) => {
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
          stats.resetCount += 1;
        }
      });
      if (result === 'sent') {
        stats.sent += 1;
      } else {
        stats.skipped += 1;
      }
    } catch (error) {
      stats.failed += 1;
      logEmailFailure(`streak_lost failed for user ${candidate.userId}`, error);
    }
  });

  return stats;
}

export async function runStreakEmailJob(referenceDate?: string): Promise<{
  today: string;
  expiredPending: number;
  atRisk: { attempted: number; sent: number; failed: number; skipped: number };
  lost: { attempted: number; sent: number; failed: number; skipped: number; resetCount: number };
}> {
  const expiredPending = await cleanupStalePendingDeliveries();
  const today = referenceDate ?? getTodayInConfiguredTimezone();
  const atRisk = await sendStreakAtRiskEmailsForDate(today, { cleanupStale: false });
  const lost = await sendStreakLostEmailsForDate(today, { cleanupStale: false });
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

async function buildRetryMessage(
  candidate: FailedDeliveryRetryCandidate,
  userName: string
): Promise<EmailMessage | null> {
  const mail = candidate.recipientEmail.trim();
  if (!mail) {
    return null;
  }

  switch (candidate.templateKey) {
    case 'welcome':
      return buildEmailMessage('welcome', { name: userName, mail });
    case 'streak_at_risk':
    case 'streak_lost': {
      const streak = await emailRepository.findUserStreakContext(candidate.userId);
      const streakCount = Math.max(1, streak?.currentCount ?? 1);
      return buildEmailMessage(candidate.templateKey, {
        name: userName,
        mail,
        streakCount
      });
    }
    default:
      return null;
  }
}

function buildRetryAfterSent(
  candidate: FailedDeliveryRetryCandidate
): ((client: PoolClient) => Promise<void>) | undefined {
  if (candidate.templateKey === 'welcome') {
    return async (client) => {
      await emailRepository.markWelcomeEmailSent(client, candidate.userId);
    };
  }

  if (candidate.templateKey === 'streak_lost') {
    return async (client) => {
      const streak = await emailRepository.findUserStreakContext(candidate.userId);
      if (streak === null || streak.currentCount <= 0) {
        return;
      }
      await emailRepository.resetExpiredStreak(client, streak.streakId);
    };
  }

  return undefined;
}

export async function runRetryFailedEmailJob(): Promise<{
  expiredPending: number;
  retry: DeliveryBatchStats;
}> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] retry_failed skipped: EMAIL_ENABLED=false or missing Brevo config');
    return {
      expiredPending: 0,
      retry: { attempted: 0, sent: 0, failed: 0, skipped: 0 }
    };
  }

  const expiredPending = await cleanupStalePendingDeliveries();
  const candidates = await emailRepository.findRetryableFailedDeliveries({
    limit: emailConfig.retryBatchLimit,
    maxAttempts: emailConfig.retryMaxAttempts,
    maxAgeHours: emailConfig.retryMaxAgeHours
  });

  const stats: DeliveryBatchStats = {
    attempted: candidates.length,
    sent: 0,
    failed: 0,
    skipped: 0
  };

  await mapWithConcurrency(candidates, emailConfig.batchConcurrency, async (candidate) => {
    const user = await emailRepository.findUserEmailContext(candidate.userId);
    const userName = user?.name?.trim() || 'Jugador';
    const message = await buildRetryMessage(candidate, userName);
    if (message === null) {
      stats.skipped += 1;
      return;
    }

    try {
      const result = await deliverTrackedEmail({
        userId: candidate.userId,
        templateKey: candidate.templateKey,
        dedupeKey: candidate.dedupeKey,
        message,
        afterSent: buildRetryAfterSent(candidate)
      });
      if (result === 'sent') {
        stats.sent += 1;
      } else {
        stats.skipped += 1;
      }
    } catch (error) {
      stats.failed += 1;
      logEmailFailure(`retry_failed delivery ${candidate.id}`, error);
    }
  });

  return { expiredPending, retry: stats };
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
