import crypto from 'crypto';
import { pool } from '../../config/database';
import { emailConfig, isEmailDeliveryConfigured } from './email.config';
import * as userRepository from '../user/user.repository';
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
  | 'dev_console'
  | 'rate_limited'
  | 'no_mail'
  | 'send_failed';

function isDevelopmentEnvironment(): boolean {
  return process.env.NODE_ENV === 'development';
}

function verificationStatusMessage(
  sendResult: SendVerificationResult,
  expiresMinutes: number
): string {
  switch (sendResult) {
    case 'sent':
      return `Te enviamos el código de verificación (no el de bienvenida). Válido por ${expiresMinutes} minutos. Revisá spam.`;
    case 'rate_limited':
      return 'Ya hay un código activo. Revisá tu casilla o esperá para reenviar.';
    case 'send_failed':
      return 'No se pudo enviar el mail. Tocá Reenviar código para intentar de nuevo.';
    case 'dev_console':
      return 'Brevo no configurado. El código de 6 dígitos está en la consola del backend (buscá dev_code).';
    case 'skipped':
      return isDevelopmentEnvironment()
        ? 'Mail no configurado. En desarrollo, el código aparece en la consola del backend.'
        : 'Servicio de mail no disponible. Contactá al administrador.';
    case 'no_mail':
      return 'No hay un mail configurado en tu cuenta.';
    default:
      return '';
  }
}

async function invalidateActiveVerificationCodes(userId: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await emailRepository.invalidatePreviousVerificationCodes(client, userId);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function buildVerificationSendMeta(
  userId: string,
  sendResult: SendVerificationResult
): Promise<{
  code_send_status: SendVerificationResult;
  cooldown_seconds: number;
  message: string;
  expires_minutes: number;
}> {
  const config = getVerificationConfig();
  const message = verificationStatusMessage(sendResult, config.expiresMinutes);
  if (sendResult === 'sent' || sendResult === 'dev_console') {
    return {
      code_send_status: sendResult,
      cooldown_seconds: sendResult === 'sent' ? config.cooldownSeconds : 0,
      message,
      expires_minutes: config.expiresMinutes
    };
  }
  if (sendResult === 'rate_limited') {
    return {
      code_send_status: sendResult,
      cooldown_seconds: await getVerificationCooldownRemainingSeconds(userId),
      message,
      expires_minutes: config.expiresMinutes
    };
  }
  return {
    code_send_status: sendResult,
    cooldown_seconds: 0,
    message,
    expires_minutes: config.expiresMinutes
  };
}

export async function sendVerificationCode(
  userId: string,
  mail: string,
  name: string,
  options?: { bypassCooldown?: boolean }
): Promise<SendVerificationResult> {
  const trimmedMail = mail.trim().toLowerCase();
  if (!trimmedMail) {
    return 'no_mail';
  }

  const lastDelivery = await emailRepository.findLatestDeliveryForUser(
    userId,
    'email_verification'
  );
  const lastSendFailed = lastDelivery?.status === 'failed';

  const lastCreatedAt = await emailRepository.getLastVerificationCodeCreatedAt(userId);
  if (lastCreatedAt && !options?.bypassCooldown && !lastSendFailed) {
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

  if (!isEmailDeliveryConfigured()) {
    if (isDevelopmentEnvironment()) {
      logInfo('dev_code', {
        userId,
        mail: trimmedMail,
        codeId,
        code,
        hint: 'Brevo no configurado — código solo en consola del backend'
      });
      logWarn('send_skipped', {
        userId,
        reason: 'email not configured',
        codeId,
        dev_code_logged: true
      });
      return 'dev_console';
    }
    await invalidateActiveVerificationCodes(userId);
    logWarn('send_skipped', {
      userId,
      reason: 'email not configured',
      codeId,
      dev_code_logged: false
    });
    return 'skipped';
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
    await invalidateActiveVerificationCodes(userId);
    logWarn('send_skipped', { userId, reason: 'email delivery skipped', codeId });
    return 'skipped';
  }

  logWarn('send_failed', {
    userId,
    mail: trimmedMail,
    codeId,
    hint: 'OTP conservado en DB — reintentá de inmediato (sin cooldown)'
  });
  return 'send_failed';
}

export type ConfirmVerificationResult = {
  status:
    | 'verified'
    | 'invalid'
    | 'expired'
    | 'no_pending'
    | 'too_many_attempts'
    | 'mail_sync_failed';
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
    const markedVerified = await emailRepository.markMailVerified(
      client,
      userId,
      active.targetMail
    );
    if (!markedVerified) {
      await client.query('ROLLBACK');
      logWarn('mail_sync_failed', {
        userId,
        targetMail: active.targetMail,
        hint: 'El mail del código no coincide con el de la cuenta. Guardá el perfil e pedí un código nuevo.'
      });
      return { status: 'mail_sync_failed' };
    }
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

export interface EmailVerificationStatusDto {
  mail: string | null;
  mail_verified_at: string | null;
  email_notifications_enabled: boolean;
  delivery_configured: boolean;
  dev_code_in_logs: boolean;
  last_verification_delivery: {
    status: 'pending' | 'sent' | 'failed';
    sent_at: string | null;
    failed_at: string | null;
    error_message: string | null;
  } | null;
  verification: {
    required: boolean;
    has_pending_code: boolean;
    pending_target_mail: string | null;
    expires_at: string | null;
    cooldown_seconds: number;
    max_attempts: number;
    attempts_remaining: number | null;
  };
}

export async function getEmailVerificationStatus(
  userId: string
): Promise<EmailVerificationStatusDto | null> {
  const user = await userRepository.findPublicUserById(userId);
  if (!user) {
    return null;
  }

  const deliveryConfigured = isEmailDeliveryConfigured();
  const config = getVerificationConfig();
  const active = await emailRepository.findActiveVerificationCode(userId);
  const cooldownSeconds = await getVerificationCooldownRemainingSeconds(userId);
  const trimmedMail = user.mail?.trim() ?? '';
  const mailVerified = user.mail_verified_at != null;
  const required = trimmedMail.length > 0 && !mailVerified;

  let attemptsRemaining: number | null = null;
  if (active && active.expiresAt >= new Date()) {
    attemptsRemaining = Math.max(0, config.maxAttempts - active.failedAttemptCount);
  }

  const lastVerificationDelivery = await emailRepository.findLatestDeliveryForUser(
    userId,
    'email_verification'
  );

  return {
    mail: trimmedMail || null,
    mail_verified_at: user.mail_verified_at ? user.mail_verified_at.toISOString() : null,
    email_notifications_enabled: user.email_notifications_enabled,
    delivery_configured: deliveryConfigured,
    dev_code_in_logs:
      isDevelopmentEnvironment() && emailConfig.enabled && !deliveryConfigured,
    last_verification_delivery: lastVerificationDelivery
      ? {
          status: lastVerificationDelivery.status,
          sent_at: lastVerificationDelivery.sent_at
            ? lastVerificationDelivery.sent_at.toISOString()
            : null,
          failed_at: lastVerificationDelivery.failed_at
            ? lastVerificationDelivery.failed_at.toISOString()
            : null,
          error_message: lastVerificationDelivery.error_message
        }
      : null,
    verification: {
      required,
      has_pending_code: active != null && active.expiresAt >= new Date(),
      pending_target_mail: active?.targetMail ?? null,
      expires_at: active ? active.expiresAt.toISOString() : null,
      cooldown_seconds: cooldownSeconds,
      max_attempts: config.maxAttempts,
      attempts_remaining: attemptsRemaining
    }
  };
}
