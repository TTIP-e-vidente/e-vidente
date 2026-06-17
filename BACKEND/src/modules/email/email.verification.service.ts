import crypto from 'crypto';
import { pool } from '../../config/database';
import { emailConfig, isEmailDeliveryConfigured } from './email.config';
import { sendTransactionalEmail } from './email.client';
import { buildEmailMessage } from './templates';
import * as emailRepository from './email.repository';

const VERIFICATION_CODE_LENGTH = 6;
const VERIFICATION_EXPIRES_MINUTES = 15;
const RESEND_COOLDOWN_SECONDS = 120;

function generateNumericCode(): string {
  // Genera código de 6 dígitos criptográficamente seguro
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

export type SendVerificationResult = 'sent' | 'skipped' | 'rate_limited' | 'no_mail';

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

  // Rate limiting: mínimo RESEND_COOLDOWN_SECONDS entre reenvíos
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

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Invalida códigos previos del mismo usuario
    await emailRepository.invalidatePreviousVerificationCodes(client, userId);
    await emailRepository.createVerificationCode(client, {
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

  // Envía el email fuera de la transacción (fail-safe: código ya persistido)
  const message = buildEmailMessage('email_verification', {
    name: name.trim() || 'Jugador',
    mail: trimmedMail,
    code,
    expiresMinutes: VERIFICATION_EXPIRES_MINUTES
  });

  try {
    await sendTransactionalEmail(message, { templateKey: 'email_verification' });
    logInfo('sent', { userId, mail: trimmedMail });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    logWarn('send_failed', { userId, error: msg });
    // El código sigue en DB — el usuario puede pedir reenvío después del cooldown
  }

  return 'sent';
}

export type ConfirmVerificationResult = 'verified' | 'invalid' | 'expired' | 'no_pending';

export async function confirmVerificationCode(
  userId: string,
  code: string
): Promise<ConfirmVerificationResult> {
  const trimmedCode = code.trim();

  const active = await emailRepository.findActiveVerificationCode(userId);
  if (!active) {
    return 'no_pending';
  }

  const inputHash = hashCode(trimmedCode);
  if (!timingSafeEqual(inputHash, active.codeHash)) {
    return 'invalid';
  }

  if (active.expiresAt < new Date()) {
    return 'expired';
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
  return 'verified';
}

export function getVerificationConfig(): {
  expiresMinutes: number;
  cooldownSeconds: number;
} {
  return {
    expiresMinutes: VERIFICATION_EXPIRES_MINUTES,
    cooldownSeconds: RESEND_COOLDOWN_SECONDS
  };
}
