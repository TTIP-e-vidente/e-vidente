import crypto from 'crypto';
import { pool } from '../../config/database';
import { isEmailDeliveryConfigured } from './email.config';
import { sendTrackedVerificationEmail } from './email.service';
import * as emailRepository from './email.repository';

const VERIFICATION_CODE_LENGTH = 6;
const VERIFICATION_EXPIRES_MINUTES = 15;
const RESEND_COOLDOWN_SECONDS = 120;
const MAX_OTP_ATTEMPTS = 5;

function generateNumericCode(): string {
  const max = 10 ** VERIFICATION_CODE_LENGTH;
  const raw = crypto.randomInt(0, max);
  return String(raw).padStart(VERIFICATION_CODE_LENGTH, '0');
}

function hashCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function timingSafeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) {
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

function logInfo(event: string, details: Record<string, unknown>): void {
  console.log(`[email:verify] ${event} ${JSON.stringify(details)}`);
}

function logWarn(event: string, details: Record<string, unknown>): void {
  console.warn(`[email:verify] ${event} ${JSON.stringify(details)}`);
}

export type SendVerificationResult =
  | 'sent'
  | 'skipped'
  | 'rate_limited'
  | 'no_mail'
  | 'send_failed';

export async function sendVerificationCode(
  userId: string,
  mail: string,
  name: string
): Promise<SendVerificationResult> {
  const trimmedMail = mail.trim();
  if (!trimmedMail) {
    return 'no_mail';
  }

  if (!isEmailDeliveryConfigured()) {
    logWarn('send_skipped', { userId, reason: 'email not configured' });
    return 'skipped';
  }

  const lastCreatedAt = await emailRepository.getLastVerificationCodeCreatedAt(userId);
  if (lastCreatedAt) {
    const secondsSinceLast = (Date.now() - lastCreatedAt.getTime()) / 1000;
    if (secondsSinceLast < RESEND_COOLDOWN_SECONDS) {
      logWarn('rate_limited', { userId, secondsSinceLast: Math.floor(secondsSinceLast) });
      return 'rate_limited';
    }
  }

  const code = generateNumericCode();
  const codeHash = hashCode(code);
  const expiresAt = new Date(Date.now() + VERIFICATION_EXPIRES_MINUTES * 60 * 1000);

  let codeId: string;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await emailRepository.invalidatePreviousVerificationCodes(client, userId);
    codeId = await emailRepository.createVerificationCode(client, {
      userId,
      codeHash,
      targetMail: trimmedMail,
      expiresAt
    });
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  const deliveryResult = await sendTrackedVerificationEmail({
    userId,
    verificationCodeId: codeId,
    name,
    mail: trimmedMail,
    code,
    expiresMinutes: VERIFICATION_EXPIRES_MINUTES
  });

  if (deliveryResult === 'sent') {
    logInfo('sent', { userId, mail: trimmedMail, codeId });
    return 'sent';
  }

  if (deliveryResult === 'skipped') {
    logWarn('send_skipped', { userId, reason: 'email not configured' });
    return 'skipped';
  }

  logWarn('send_failed', { userId, mail: trimmedMail, codeId });
  return 'send_failed';
}

export type ConfirmVerificationResult = {
  status: 'verified' | 'invalid' | 'expired' | 'no_pending' | 'too_many_attempts';
  attemptsRemaining?: number;
};

export async function confirmVerificationCode(
  userId: string,
  code: string
): Promise<ConfirmVerificationResult> {
  const trimmedCode = code.trim();

  const active = await emailRepository.findActiveVerificationCode(userId);
  if (!active) {
    return { status: 'no_pending' };
  }

  if (active.expiresAt < new Date()) {
    return { status: 'expired' };
  }

  const inputHash = hashCode(trimmedCode);
  if (!timingSafeEqual(inputHash, active.codeHash)) {
    const attempts = await emailRepository.incrementVerificationFailedAttempts(active.id);
    const attemptsRemaining = Math.max(0, MAX_OTP_ATTEMPTS - attempts);
    if (attempts >= MAX_OTP_ATTEMPTS) {
      const lockClient = await pool.connect();
      try {
        await lockClient.query('BEGIN');
        await emailRepository.invalidatePreviousVerificationCodes(lockClient, userId);
        await lockClient.query('COMMIT');
      } catch {
        await lockClient.query('ROLLBACK');
      } finally {
        lockClient.release();
      }
      logWarn('too_many_attempts', { userId, attempts });
      return { status: 'too_many_attempts', attemptsRemaining: 0 };
    }
    logWarn('invalid_attempt', { userId, attempts, remaining: attemptsRemaining });
    return { status: 'invalid', attemptsRemaining };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await emailRepository.markVerificationCodeUsed(client, active.id);
    await emailRepository.markMailVerified(client, userId, active.targetMail);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  logInfo('verified', { userId, mail: active.targetMail });
  return { status: 'verified' };
}

export function getVerificationConfig(): {
  expiresMinutes: number;
  cooldownSeconds: number;
  maxAttempts: number;
} {
  return {
    expiresMinutes: VERIFICATION_EXPIRES_MINUTES,
    cooldownSeconds: RESEND_COOLDOWN_SECONDS,
    maxAttempts: MAX_OTP_ATTEMPTS
  };
}

export async function getVerificationCooldownRemainingSeconds(userId: string): Promise<number> {
  const config = getVerificationConfig();
  const lastCreatedAt = await emailRepository.getLastVerificationCodeCreatedAt(userId);
  if (!lastCreatedAt) {
    return 0;
  }
  const secondsSinceLast = (Date.now() - lastCreatedAt.getTime()) / 1000;
  return Math.max(0, Math.ceil(config.cooldownSeconds - secondsSinceLast));
}
