import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import {
  AuthError,
  ConfigError,
  requireAnonKey,
  verifyExpressAccessToken,
  VERIFICATION_TOKEN_SCOPE,
} from '../_shared/jwt.ts';
import { findPublicUserById, withDb } from '../_shared/db.ts';
import { normalizeMail } from '../_shared/crypto.ts';
import {
  getLatestDeliveryError,
  getVerificationConfig,
  getVerificationCooldownRemainingSeconds,
  sendVerificationCode,
} from '../_shared/verification.ts';
import { isDevelopmentEnvironment, isEmailDeliveryConfigured } from '../_shared/brevo.ts';

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) {
    return cors;
  }

  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed');
  }

  try {
    requireAnonKey(req);
    // Acepta también el token acotado que devuelve auth-login (EMAIL_NOT_VERIFIED).
    const { sub: userId } = await verifyExpressAccessToken(req.headers.get('Authorization'), {
      allowScopes: [VERIFICATION_TOKEN_SCOPE],
    });

    const user = await withDb(async (db) => findPublicUserById(db, userId));
    if (!user) {
      return errorResponse(401, 'Unauthorized');
    }

    if (!user.mail) {
      return errorResponse(422, 'No tenés un email configurado en tu cuenta.');
    }

    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const requestedMail = typeof body.mail === 'string' ? body.mail.trim() : '';
    if (
      requestedMail &&
      normalizeMail(requestedMail) !== normalizeMail(user.mail)
    ) {
      return jsonResponse(
        {
          error: 'Guardá el mail en tu perfil antes de pedir el código.',
          code: 'MAIL_OUT_OF_SYNC',
          mail: user.mail,
        },
        409,
      );
    }

    if (user.mail_verified_at) {
      return jsonResponse({
        status: 'already_verified',
        message: 'Tu email ya está verificado.',
        mail: user.mail,
        mail_verified_at: user.mail_verified_at.toISOString(),
      });
    }

    const config = getVerificationConfig();
    const result = await sendVerificationCode(userId, user.mail, user.name);

    if (result === 'sent') {
      return jsonResponse({
        status: 'sent',
        message: `Código de verificación enviado a ${user.mail}. Revisá spam. Válido por ${config.expiresMinutes} minutos.`,
        expires_minutes: config.expiresMinutes,
        cooldown_seconds: config.cooldownSeconds,
      });
    }

    if (result === 'dev_console') {
      return jsonResponse({
        status: 'dev_console',
        message:
          'Brevo no configurado. El código de 6 dígitos está en los logs de la Edge Function (dev_code).',
        dev_code_in_logs: true,
        expires_minutes: config.expiresMinutes,
        cooldown_seconds: 0,
      });
    }

    if (result === 'rate_limited') {
      const cooldownSeconds = await getVerificationCooldownRemainingSeconds(userId);
      return jsonResponse(
        {
          error: `Esperá ${cooldownSeconds} segundos antes de pedir otro código.`,
          code: 'RATE_LIMITED',
          cooldown_seconds: cooldownSeconds,
        },
        429,
      );
    }

    if (result === 'send_failed') {
      const detail = await getLatestDeliveryError(userId);
      return jsonResponse(
        {
          error: detail
            ? `No se pudo enviar el código: ${detail}`
            : 'No se pudo enviar el código. Intentá de nuevo en unos minutos.',
          code: 'SEND_FAILED',
          ...(detail ? { detail } : {}),
        },
        503,
      );
    }

    if (result === 'skipped') {
      const brevoMissing = !isEmailDeliveryConfigured();
      return jsonResponse(
        {
          error: brevoMissing
            ? isDevelopmentEnvironment()
              ? 'Brevo no está configurado en Supabase Edge Functions.'
              : 'Servicio de email no disponible. Contactá al administrador.'
            : 'Servicio de email no disponible.',
          code: 'EMAIL_UNAVAILABLE',
          dev_code_in_logs: brevoMissing && isDevelopmentEnvironment(),
        },
        503,
      );
    }

    return errorResponse(422, 'No tenés un email configurado.');
  } catch (error) {
    if (error instanceof AuthError) {
      return jsonResponse({ error: 'Invalid token', code: 'INVALID_CREDENTIALS' }, 401);
    }
    if (error instanceof ConfigError) {
      return errorResponse(503, error.message);
    }
    console.error('[verify-email-request]', error);
    return errorResponse(500, 'Internal server error');
  }
});
