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
  ListEmailDeliveriesFilters,
  PendingWelcomeDelivery
} from './email.types';

function logEmailFailure(context: string, error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  console.warn(`[email] ${context}: ${message}`);
}

function logEmailInfo(event: string, details: Record<string, unknown>): void {
  console.log(`[email] ${event} ${JSON.stringify(details)}`);
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

async function cleanupStalePendingDeliveries(): Promise<number> {
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
    const providerMessageId = await sendTransactionalEmail(input.message, {
      templateKey: input.templateKey
    });

    const postClient = await pool.connect();
    try {
      await postClient.query('BEGIN');
      await emailRepository.markDeliverySent(postClient, deliveryId, providerMessageId);
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

async function dispatchPendingWelcomeDelivery(
  pending: PendingWelcomeDelivery
): Promise<'sent' | 'failed'> {
  const user = await emailRepository.findUserEmailContext(pending.userId);
  const userName = user?.name?.trim() || 'Jugador';
  const mail = pending.recipientEmail.trim();
  if (!mail) {
    await emailRepository.markDeliveryFailed(pending.id, 'Missing recipient email');
    return 'failed';
  }

  const message = buildEmailMessage('welcome', { name: userName, mail });

  try {
    const providerMessageId = await sendTransactionalEmail(message, { templateKey: 'welcome' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await emailRepository.markDeliverySent(client, pending.id, providerMessageId);
      await emailRepository.markWelcomeEmailSent(client, pending.userId);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
    return 'sent';
  } catch (error) {
    await emailRepository.markDeliveryFailed(pending.id, formatDeliveryError(error));
    throw error;
  }
}

export async function enqueueWelcomeEmail(
  recipient: EmailRecipient
): Promise<'queued' | 'skipped'> {
  if (!recipient.mail) {
    return 'skipped';
  }
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] welcome skipped: EMAIL_ENABLED=false or missing Brevo config');
    return 'skipped';
  }
  if (await shouldSkipWelcomeEmail(recipient.userId)) {
    return 'skipped';
  }

  const message = buildEmailMessage('welcome', {
    name: recipient.name,
    mail: recipient.mail
  });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const deliveryId = await emailRepository.acquireDeliverySlot(client, {
      userId: recipient.userId,
      templateKey: 'welcome',
      dedupeKey: 'welcome',
      recipientEmail: message.to,
      subject: message.subject
    });
    if (!deliveryId) {
      await client.query('ROLLBACK');
      return 'skipped';
    }
    await client.query('COMMIT');
    logEmailInfo('welcome_queued', { userId: recipient.userId, deliveryId });
    return 'queued';
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function processPendingWelcomeEmails(): Promise<DeliveryBatchStats> {
  if (!isEmailDeliveryConfigured()) {
    return { attempted: 0, sent: 0, failed: 0, skipped: 0 };
  }

  await cleanupStalePendingDeliveries();
  const pending = await emailRepository.findPendingWelcomeDeliveries(
    emailConfig.pendingWelcomeBatchLimit
  );
  const stats: DeliveryBatchStats = {
    attempted: pending.length,
    sent: 0,
    failed: 0,
    skipped: 0
  };

  for (const row of pending) {
    try {
      const result = await dispatchPendingWelcomeDelivery(row);
      if (result === 'sent') {
        stats.sent += 1;
      }
    } catch (error) {
      stats.failed += 1;
      logEmailFailure(`pending welcome ${row.id}`, error);
    }
  }

  return stats;
}

async function sendWelcomeEmail(recipient: EmailRecipient): Promise<void> {
  const queued = await enqueueWelcomeEmail(recipient);
  if (queued === 'queued') {
    scheduleOutboundEmailJob();
  }
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
        message
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
  reconciledStreaks: number;
}> {
  const expiredPending = await cleanupStalePendingDeliveries();
  const today = referenceDate ?? getTodayInConfiguredTimezone();
  const atRisk = await sendStreakAtRiskEmailsForDate(today, { cleanupStale: false });
  const lost = await sendStreakLostEmailsForDate(today, { cleanupStale: false });
  const reconciledStreaks = await emailRepository.reconcileExpiredStreaksInDatabase(today);

  if (reconciledStreaks > 0) {
    logEmailInfo('streaks_reconciled', { today, reconciledStreaks });
  }

  return {
    today,
    expiredPending,
    atRisk,
    lost: { ...lost, resetCount: reconciledStreaks },
    reconciledStreaks
  };
}

export async function runOutboundEmailJob(referenceDate?: string): Promise<{
  today: string;
  expiredPending: number;
  pendingWelcome: DeliveryBatchStats;
  atRisk: DeliveryBatchStats;
  lost: DeliveryBatchStats & { resetCount: number };
  reconciledStreaks: number;
  retry: DeliveryBatchStats;
}> {
  if (!isEmailDeliveryConfigured()) {
    console.warn('[email] outbound skipped: EMAIL_ENABLED=false or missing Brevo config');
    return {
      today: referenceDate ?? getTodayInConfiguredTimezone(),
      expiredPending: 0,
      pendingWelcome: { attempted: 0, sent: 0, failed: 0, skipped: 0 },
      atRisk: { attempted: 0, sent: 0, failed: 0, skipped: 0 },
      lost: { attempted: 0, sent: 0, failed: 0, skipped: 0, resetCount: 0 },
      reconciledStreaks: 0,
      retry: { attempted: 0, sent: 0, failed: 0, skipped: 0 }
    };
  }

  const expiredPending = await cleanupStalePendingDeliveries();
  const today = referenceDate ?? getTodayInConfiguredTimezone();
  const pendingWelcome = await processPendingWelcomeEmails();
  const atRisk = await sendStreakAtRiskEmailsForDate(today, { cleanupStale: false });
  const lost = await sendStreakLostEmailsForDate(today, { cleanupStale: false });
  const reconciledStreaks = await emailRepository.reconcileExpiredStreaksInDatabase(today);
  const retryResult = await runRetryFailedEmailJob();

  const summary = {
    today,
    expiredPending,
    pendingWelcome,
    atRisk,
    lost: { ...lost, resetCount: reconciledStreaks },
    reconciledStreaks,
    retry: retryResult.retry
  };
  logEmailInfo('outbound_completed', summary);
  return summary;
}

export function scheduleOutboundEmailJob(referenceDate?: string): void {
  if (!isEmailDeliveryConfigured()) {
    return;
  }
  void runOutboundEmailJob(referenceDate).catch((error) => {
    logEmailFailure('outbound_background', error);
  });
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
