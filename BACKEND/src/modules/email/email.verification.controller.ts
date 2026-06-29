import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import * as userRepository from '../user/user.repository';
import { queueWelcomeEmail } from './email.service';
import {
  confirmVerificationCode,
  getEmailVerificationStatus,
  getVerificationConfig,
  getVerificationCooldownRemainingSeconds,
  sendVerificationCode
} from './email.verification.service';
import { isEmailDeliveryConfigured } from './email.config';
import * as emailRepository from './email.repository';
import { isSupabaseEmailEdgeMode } from '../../config/supabase-email-mode';

function rejectIfEmailViaSupabaseEdge(response: Response): boolean {
  if (!isSupabaseEmailEdgeMode()) {
    return false;
  }
  sendResponse(response, 410, {
    error: 'La verificación de mail corre en Supabase Edge Functions.',
    code: 'EMAIL_VIA_SUPABASE_EDGE',
    hint: 'Godot debe usar verify-email-request/confirm en Supabase (npm run sync:godot-config:staging)',
  });
  return true;
}

function isDevelopmentEnvironment(): boolean {
  return process.env.NODE_ENV === 'development';
}

function normalizeMailForCompare(value: string | null | undefined): string {
  if (value == null) {
    return '';
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed.toLowerCase() : '';
}

export async function getEmailStatusController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const userId = request.user?.id;
    if (!userId) {
      sendResponse(response, 401, { error: 'Unauthorized' });
      return;
    }

    const status = await getEmailVerificationStatus(userId);
    if (!status) {
      sendResponse(response, 401, { error: 'Unauthorized' });
      return;
    }

    sendResponse(response, 200, status);
  } catch (error) {
    sendError(response, error);
  }
}

export async function requestVerificationController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    if (rejectIfEmailViaSupabaseEdge(response)) {
      return;
    }
    const userId = request.user?.id;
    if (!userId) {
      sendResponse(response, 401, { error: 'Unauthorized' });
      return;
    }

    const user = await userRepository.findPublicUserById(userId);
    if (!user) {
      sendResponse(response, 401, { error: 'Unauthorized' });
      return;
    }

    if (!user.mail) {
      sendResponse(response, 422, { error: 'No tenés un email configurado en tu cuenta.' });
      return;
    }

    const body = (request.body ?? {}) as Record<string, unknown>;
    const requestedMail = typeof body.mail === 'string' ? body.mail.trim() : '';
    if (
      requestedMail &&
      normalizeMailForCompare(requestedMail) !== normalizeMailForCompare(user.mail)
    ) {
      sendResponse(response, 409, {
        error: 'Guardá el mail en tu perfil antes de pedir el código.',
        code: 'MAIL_OUT_OF_SYNC',
        mail: user.mail
      });
      return;
    }

    if (user.mail_verified_at) {
      sendResponse(response, 200, {
        status: 'already_verified',
        message: 'Tu email ya está verificado.',
        mail: user.mail,
        mail_verified_at: user.mail_verified_at
      });
      return;
    }

    const config = getVerificationConfig();
    const result = await sendVerificationCode(userId, user.mail, user.name);

    if (result === 'sent') {
      sendResponse(response, 200, {
        status: 'sent',
        message: `Código de verificación enviado a ${user.mail}. Revisá spam. Válido por ${config.expiresMinutes} minutos. El mail de bienvenida llega después de confirmar el código.`,
        expires_minutes: config.expiresMinutes,
        cooldown_seconds: config.cooldownSeconds
      });
      return;
    }

    if (result === 'dev_console') {
      sendResponse(response, 200, {
        status: 'dev_console',
        message:
          'Brevo no configurado. El código de 6 dígitos está en la consola del backend (evento dev_code).',
        dev_code_in_logs: true,
        expires_minutes: config.expiresMinutes,
        cooldown_seconds: 0
      });
      return;
    }

    if (result === 'rate_limited') {
      const cooldownSeconds = await getVerificationCooldownRemainingSeconds(userId);
      sendResponse(response, 429, {
        error: `Esperá ${cooldownSeconds} segundos antes de pedir otro código.`,
        code: 'RATE_LIMITED',
        cooldown_seconds: cooldownSeconds
      });
      return;
    }

    if (result === 'send_failed') {
      const lastDelivery = await emailRepository.findLatestDeliveryForUser(
        userId,
        'email_verification'
      );
      const detail = lastDelivery?.error_message?.trim() ?? '';
      sendResponse(response, 503, {
        error: detail
          ? `No se pudo enviar el código: ${detail}`
          : 'No se pudo enviar el código. Intentá de nuevo en unos minutos.',
        code: 'SEND_FAILED',
        ...(detail ? { detail } : {})
      });
      return;
    }

    if (result === 'skipped') {
      const brevoMissing = !isEmailDeliveryConfigured();
      sendResponse(response, 503, {
        error: brevoMissing
          ? isDevelopmentEnvironment()
            ? 'Brevo no está configurado en el backend. Revisá BACKEND/.env.staging (BREVO_API_KEY, BREVO_SENDER_EMAIL) y reiniciá npm run dev.'
            : 'Servicio de email no disponible. Contactá al administrador.'
          : 'Servicio de email no disponible.',
        code: 'EMAIL_UNAVAILABLE',
        dev_code_in_logs: brevoMissing && isDevelopmentEnvironment()
      });
      return;
    }

    sendResponse(response, 422, { error: 'No tenés un email configurado.' });
  } catch (error) {
    sendError(response, error);
  }
}

export async function confirmVerificationController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    if (rejectIfEmailViaSupabaseEdge(response)) {
      return;
    }
    const userId = request.user?.id;
    if (!userId) {
      sendResponse(response, 401, { error: 'Unauthorized' });
      return;
    }

    const body = request.body as Record<string, unknown>;
    const code = typeof body.code === 'string' ? body.code.trim() : '';

    if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
      sendResponse(response, 400, { error: 'El código debe ser de 6 dígitos numéricos.' });
      return;
    }

    const config = getVerificationConfig();
    const result = await confirmVerificationCode(userId, code);

    if (result.status === 'verified') {
      const user = await userRepository.findPublicUserById(userId);
      if (user?.mail) {
        queueWelcomeEmail({
          userId,
          mail: user.mail,
          name: user.name
        });
      }
      sendResponse(response, 200, {
        status: 'verified',
        message: '¡Email verificado correctamente!',
        mail_verified_at: user?.mail_verified_at ?? null
      });
      return;
    }

    if (result.status === 'invalid') {
      const remaining = result.attemptsRemaining ?? 0;
      sendResponse(response, 422, {
        error:
          remaining > 0
            ? `Código incorrecto. Te quedan ${remaining} intento${remaining === 1 ? '' : 's'}.`
            : 'Código incorrecto. Verificá e intentá de nuevo.',
        code: 'INVALID_CODE',
        attempts_remaining: remaining,
        max_attempts: config.maxAttempts
      });
      return;
    }

    if (result.status === 'too_many_attempts') {
      sendResponse(response, 429, {
        error: 'Demasiados intentos incorrectos. El código fue invalidado. Solicitá uno nuevo.',
        code: 'TOO_MANY_ATTEMPTS',
        attempts_remaining: 0,
        max_attempts: config.maxAttempts
      });
      return;
    }

    if (result.status === 'mail_sync_failed') {
      sendResponse(response, 409, {
        error:
          'El mail de tu cuenta no coincide con el del código. Guardá el perfil e pedí un código nuevo.',
        code: 'MAIL_OUT_OF_SYNC'
      });
      return;
    }

    if (result.status === 'expired') {
      sendResponse(response, 422, {
        error: 'El código expiró. Solicitá uno nuevo.',
        code: 'CODE_EXPIRED'
      });
      return;
    }

    sendResponse(response, 422, {
      error: 'No hay un código de verificación pendiente. Solicitá uno primero.',
      code: 'NO_PENDING_CODE'
    });
  } catch (error) {
    sendError(response, error);
  }
}
