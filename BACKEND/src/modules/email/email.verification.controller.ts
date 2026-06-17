import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import * as userRepository from '../user/user.repository';
import {
  confirmVerificationCode,
  getVerificationConfig,
  sendVerificationCode
} from './email.verification.service';

export async function requestVerificationController(
  request: Request,
  response: Response
): Promise<void> {
  try {
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
        message: `Código enviado a ${user.mail}. Válido por ${config.expiresMinutes} minutos.`,
        expires_minutes: config.expiresMinutes,
        cooldown_seconds: config.cooldownSeconds
      });
      return;
    }

    if (result === 'rate_limited') {
      sendResponse(response, 429, {
        error: `Esperá ${config.cooldownSeconds} segundos antes de pedir otro código.`,
        cooldown_seconds: config.cooldownSeconds
      });
      return;
    }

    if (result === 'skipped') {
      sendResponse(response, 503, { error: 'Servicio de email no disponible.' });
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

    const result = await confirmVerificationCode(userId, code);

    if (result === 'verified') {
      const user = await userRepository.findPublicUserById(userId);
      sendResponse(response, 200, {
        status: 'verified',
        message: '¡Email verificado correctamente!',
        mail_verified_at: user?.mail_verified_at ?? null
      });
      return;
    }

    if (result === 'invalid') {
      sendResponse(response, 422, {
        error: 'Código incorrecto. Verificá e intentá de nuevo.',
        code: 'INVALID_CODE'
      });
      return;
    }

    if (result === 'expired') {
      sendResponse(response, 422, {
        error: 'El código expiró. Solicitá uno nuevo.',
        code: 'CODE_EXPIRED'
      });
      return;
    }

    // no_pending
    sendResponse(response, 422, {
      error: 'No hay un código de verificación pendiente. Solicitá uno primero.',
      code: 'NO_PENDING_CODE'
    });
  } catch (error) {
    sendError(response, error);
  }
}
