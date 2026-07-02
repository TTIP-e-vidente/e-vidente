import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';
import {
  buildAccountVerifiedEmail,
  buildVerificationEmail,
  isDevelopmentEnvironment,
  isEmailDeliveryConfigured,
  sendTransactionalEmail,
} from './brevo.ts';
import { generateNumericCode, hashCode, normalizeMail, timingSafeEqual } from './crypto.ts';
import { findPublicUserById, withDb, withTransaction } from './db.ts';
import { deliverTrackedEmail } from './delivery.ts';

const VERIFICATION_EXPIRES_MINUTES = 15;
const RESEND_COOLDOWN_SECONDS = 120;
const MAX_OTP_ATTEMPTS = 5;

export type SendVerificationResult =
  | 'sent'
  | 'skipped'
  | 'dev_console'
  | 'rate_limited'
  | 'no_mail'
  | 'send_failed';

interface ActiveCodeRow {
  id: string;
  code_hash: string;
  target_mail: string;
  expires_at: Date;
  failed_attempt_count: number;
}

interface DeliveryRow {
  status: 'pending' | 'sent' | 'failed';
  error_message: string | null;
}

function logInfo(event: string, details: Record<string, unknown>): void {
  console.log(`[edge:verify] ${event}`, JSON.stringify(details));
}

function logWarn(event: string, details: Record<string, unknown>): void {
  console.warn(`[edge:verify] ${event}`, JSON.stringify(details));
}

export function getVerificationConfig() {
  return {
    expiresMinutes: VERIFICATION_EXPIRES_MINUTES,
    cooldownSeconds: RESEND_COOLDOWN_SECONDS,
    maxAttempts: MAX_OTP_ATTEMPTS,
  };
}

async function findLatestDelivery(
  db: Client,
  userId: string,
): Promise<DeliveryRow | null> {
  const result = await db.queryObject<DeliveryRow>(
    `
      SELECT status, error_message
      FROM email_deliveries
      WHERE user_id = $1 AND template_key = 'email_verification'
      ORDER BY created_at DESC
      LIMIT 1;
    `,
    [userId],
  );
  return result.rows[0] ?? null;
}

async function getLastCodeCreatedAt(
  db: Client,
  userId: string,
): Promise<Date | null> {
  const result = await db.queryObject<{ created_at: Date }>(
    `
      SELECT created_at
      FROM email_verification_codes
      WHERE user_id = $1
        AND used_at IS NULL
        AND expires_at > now()
      ORDER BY created_at DESC
      LIMIT 1;
    `,
    [userId],
  );
  return result.rows[0]?.created_at ?? null;
}

async function findActiveCode(
  db: Client,
  userId: string,
): Promise<ActiveCodeRow | null> {
  const result = await db.queryObject<ActiveCodeRow>(
    `
      SELECT id, code_hash, target_mail, expires_at, failed_attempt_count
      FROM email_verification_codes
      WHERE user_id = $1
        AND used_at IS NULL
        AND expires_at > now()
      ORDER BY created_at DESC
      LIMIT 1;
    `,
    [userId],
  );
  return result.rows[0] ?? null;
}

async function acquireDeliverySlot(
  db: Client,
  input: {
    userId: string;
    templateKey: string;
    dedupeKey: string;
    recipientEmail: string;
    subject: string;
  },
): Promise<string | null> {
  const existing = await db.queryObject<{ id: string; status: string }>(
    `
      SELECT id, status
      FROM email_deliveries
      WHERE user_id = $1 AND template_key = $2 AND dedupe_key = $3;
    `,
    [input.userId, input.templateKey, input.dedupeKey],
  );
  const row = existing.rows[0];
  if (row?.status === 'sent' || row?.status === 'pending') {
    return null;
  }
  if (row?.status === 'failed') {
    const retry = await db.queryObject<{ id: string }>(
      `
        UPDATE email_deliveries
        SET status = 'pending', recipient_email = $2, subject = $3,
            provider_message_id = NULL, error_message = NULL,
            failed_at = NULL, sent_at = NULL, attempt_count = attempt_count + 1,
            last_attempt_at = now(), next_attempt_at = NULL
        WHERE id = $1
        RETURNING id;
      `,
      [row.id, input.recipientEmail, input.subject],
    );
    return retry.rows[0]?.id ?? null;
  }
  const created = await db.queryObject<{ id: string }>(
    `
      INSERT INTO email_deliveries (
        user_id, template_key, dedupe_key, recipient_email, subject, status
      ) VALUES ($1, $2, $3, $4, $5, 'pending')
      RETURNING id;
    `,
    [
      input.userId,
      input.templateKey,
      input.dedupeKey,
      input.recipientEmail,
      input.subject,
    ],
  );
  return created.rows[0]?.id ?? null;
}

async function markDeliverySent(
  db: Client,
  deliveryId: string,
  providerMessageId: string | null,
): Promise<void> {
  await db.queryObject(
    `
      UPDATE email_deliveries
      SET status = 'sent', sent_at = now(), provider_message_id = $2, error_message = NULL,
          last_attempt_at = now(), next_attempt_at = NULL, locked_at = NULL, locked_by = NULL
      WHERE id = $1;
    `,
    [deliveryId, providerMessageId],
  );
}

// Backoff simple entre reintentos: 2.º intento +10 min, 3.º +1 h, 4.º+ +6 h.
async function markDeliveryFailed(
  db: Client,
  deliveryId: string,
  errorMessage: string,
): Promise<void> {
  await db.queryObject(
    `
      UPDATE email_deliveries
      SET status = 'failed', error_message = $2, failed_at = now(), sent_at = NULL,
          last_attempt_at = now(), locked_at = NULL, locked_by = NULL,
          next_attempt_at = now() + (
            CASE
              WHEN attempt_count <= 1 THEN INTERVAL '10 minutes'
              WHEN attempt_count = 2 THEN INTERVAL '1 hour'
              ELSE INTERVAL '6 hours'
            END
          )
      WHERE id = $1;
    `,
    [deliveryId, errorMessage.slice(0, 1000)],
  );
}

async function invalidateActiveCodes(db: Client, userId: string): Promise<void> {
  await db.queryObject(
    `
      UPDATE email_verification_codes
      SET used_at = now()
      WHERE user_id = $1 AND used_at IS NULL;
    `,
    [userId],
  );
}

async function deliverTrackedVerification(input: {
  userId: string;
  verificationCodeId: string;
  name: string;
  mail: string;
  code: string;
}): Promise<'sent' | 'failed' | 'skipped'> {
  const message = buildVerificationEmail({
    name: input.name,
    mail: input.mail,
    code: input.code,
    expiresMinutes: VERIFICATION_EXPIRES_MINUTES,
  });

  let deliveryId: string | null = null;
  await withTransaction(async (db) => {
    deliveryId = await acquireDeliverySlot(db, {
      userId: input.userId,
      templateKey: 'email_verification',
      dedupeKey: `verify:${input.userId}:${input.verificationCodeId}`,
      recipientEmail: message.to,
      subject: message.subject,
    });
  });

  if (!deliveryId) {
    return 'skipped';
  }

  try {
    const providerMessageId = await sendTransactionalEmail(
      message,
      'email_verification',
    );
    await withDb(async (db) => {
      await markDeliverySent(db, deliveryId!, providerMessageId);
    });
    return 'sent';
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    await withDb(async (db) => {
      await markDeliveryFailed(db, deliveryId!, msg);
    });
    return 'failed';
  }
}

export async function getVerificationCooldownRemainingSeconds(
  userId: string,
): Promise<number> {
  return withDb(async (db) => {
    const lastCreatedAt = await getLastCodeCreatedAt(db, userId);
    if (!lastCreatedAt) {
      return 0;
    }
    const secondsSinceLast = (Date.now() - lastCreatedAt.getTime()) / 1000;
    return Math.max(0, Math.ceil(RESEND_COOLDOWN_SECONDS - secondsSinceLast));
  });
}

export async function sendVerificationCode(
  userId: string,
  mail: string,
  name: string,
): Promise<SendVerificationResult> {
  const trimmedMail = normalizeMail(mail);
  if (!trimmedMail) {
    return 'no_mail';
  }

  const txResult = await withTransaction(async (db) => {
    const lastDelivery = await findLatestDelivery(db, userId);
    const lastSendFailed = lastDelivery?.status === 'failed';
    const lastCreatedAt = await getLastCodeCreatedAt(db, userId);
    if (lastCreatedAt && !lastSendFailed) {
      const secondsSinceLast = (Date.now() - lastCreatedAt.getTime()) / 1000;
      if (secondsSinceLast < RESEND_COOLDOWN_SECONDS) {
        return { kind: 'rate_limited' as const };
      }
    }

    const otp = generateNumericCode();
    const codeHash = await hashCode(otp);
    const expiresAt = new Date(
      Date.now() + VERIFICATION_EXPIRES_MINUTES * 60 * 1000,
    );
    await invalidateActiveCodes(db, userId);
    const inserted = await db.queryObject<{ id: string }>(
      `
        INSERT INTO email_verification_codes (user_id, code_hash, target_mail, expires_at)
        VALUES ($1, $2, $3, $4)
        RETURNING id;
      `,
      [userId, codeHash, trimmedMail, expiresAt],
    );
    return {
      kind: 'created' as const,
      codeId: inserted.rows[0]?.id ?? '',
      code: otp,
    };
  });

  if (txResult.kind === 'rate_limited') {
    logWarn('rate_limited', { userId });
    return 'rate_limited';
  }

  const { codeId, code } = txResult;

  if (!isEmailDeliveryConfigured()) {
    if (isDevelopmentEnvironment()) {
      logInfo('dev_code', { userId, mail: trimmedMail, codeId, code });
      return 'dev_console';
    }
    await withDb(async (db) => invalidateActiveCodes(db, userId));
    return 'skipped';
  }

  const deliveryResult = await deliverTrackedVerification({
    userId,
    verificationCodeId: codeId,
    name,
    mail: trimmedMail,
    code,
  });

  if (deliveryResult === 'sent') {
    logInfo('sent', { userId, mail: trimmedMail, codeId });
    return 'sent';
  }
  if (deliveryResult === 'skipped') {
    await withDb(async (db) => invalidateActiveCodes(db, userId));
    return 'skipped';
  }

  logWarn('send_failed', { userId, mail: trimmedMail, codeId });
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
  mailVerifiedAt?: string | null;
};

export async function confirmVerificationCode(
  userId: string,
  code: string,
): Promise<ConfirmVerificationResult> {
  const trimmedCode = code.trim();

  const active = await withDb(async (db) => findActiveCode(db, userId));
  if (!active) {
    return { status: 'no_pending' };
  }
  if (active.expires_at < new Date()) {
    return { status: 'expired' };
  }

  const inputHash = await hashCode(trimmedCode);
  if (!timingSafeEqual(inputHash, active.code_hash)) {
    const attempts = await withDb(async (db) => {
      const result = await db.queryObject<{ failed_attempt_count: number }>(
        `
          UPDATE email_verification_codes
          SET failed_attempt_count = failed_attempt_count + 1
          WHERE id = $1
          RETURNING failed_attempt_count;
        `,
        [active.id],
      );
      return result.rows[0]?.failed_attempt_count ?? 0;
    });

    const attemptsRemaining = Math.max(0, MAX_OTP_ATTEMPTS - attempts);
    if (attempts >= MAX_OTP_ATTEMPTS) {
      await withDb(async (db) => invalidateActiveCodes(db, userId));
      return { status: 'too_many_attempts', attemptsRemaining: 0 };
    }
    return { status: 'invalid', attemptsRemaining };
  }

  const verified = await withTransaction(async (db) => {
    await db.queryObject(
      `UPDATE email_verification_codes SET used_at = now() WHERE id = $1;`,
      [active.id],
    );
    const normalizedMail = normalizeMail(active.target_mail);
    const result = await db.queryObject<{ mail_verified_at: Date }>(
      `
        UPDATE users
        SET mail_verified_at = now(), updated_at = now()
        WHERE id = $1
          AND mail_verified_at IS NULL
          AND lower(trim(coalesce(mail, ''))) = $2
        RETURNING mail_verified_at;
      `,
      [userId, normalizedMail],
    );
    return result.rows[0]?.mail_verified_at ?? null;
  });

  if (!verified) {
    return { status: 'mail_sync_failed' };
  }

  logInfo('verified', { userId, mail: active.target_mail });

  // Mail "cuenta verificada": transaccional propio, vía outbox (email_deliveries)
  // con dedupe account_verified:{userId}. Si Brevo falla, la fila queda failed
  // y la retoma el job de retry. Nunca bloquea la respuesta de verificación.
  const user = await withDb(async (db) => findPublicUserById(db, userId));
  if (user?.mail && isEmailDeliveryConfigured()) {
    try {
      const message = buildAccountVerifiedEmail({ name: user.name, mail: user.mail });
      const result = await deliverTrackedEmail({
        userId,
        templateKey: 'account_verified',
        dedupeKey: `account_verified:${userId}`,
        message,
      });
      logInfo('account_verified_delivery', { userId, result });
    } catch (error) {
      logWarn('account_verified_failed', {
        userId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return {
    status: 'verified',
    mailVerifiedAt: verified.toISOString(),
  };
}

function verificationStatusMessage(
  sendResult: SendVerificationResult,
  expiresMinutes: number,
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

export async function buildVerificationSendMeta(
  userId: string,
  sendResult: SendVerificationResult,
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
      expires_minutes: config.expiresMinutes,
    };
  }
  if (sendResult === 'rate_limited') {
    return {
      code_send_status: sendResult,
      cooldown_seconds: await getVerificationCooldownRemainingSeconds(userId),
      message,
      expires_minutes: config.expiresMinutes,
    };
  }
  return {
    code_send_status: sendResult,
    cooldown_seconds: 0,
    message,
    expires_minutes: config.expiresMinutes,
  };
}

export async function getLatestDeliveryError(userId: string): Promise<string> {
  return withDb(async (db) => {
    const row = await findLatestDelivery(db, userId);
    return row?.error_message?.trim() ?? '';
  });
}
