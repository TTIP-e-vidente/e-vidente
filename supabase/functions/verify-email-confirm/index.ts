import { handleCors, jsonResponse, errorResponse } from '../_shared/cors.ts';
import {
  AuthError,
  ConfigError,
  requireAnonKey,
  verifyExpressAccessToken,
  VERIFICATION_TOKEN_SCOPE,
} from '../_shared/jwt.ts';
import { findPublicUserById, withDb } from '../_shared/db.ts';
import { issueAccessTokenForUserId } from '../_shared/auth.ts';
import {
  confirmVerificationCode,
  getVerificationConfig,
} from '../_shared/verification.ts';

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

    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const code = typeof body.code === 'string' ? body.code.trim() : '';

    if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
      return errorResponse(400, 'El código debe ser de 6 dígitos numéricos.');
    }

    const config = getVerificationConfig();
    const result = await confirmVerificationCode(userId, code);

    if (result.status === 'verified') {
      const user = await withDb(async (db) => findPublicUserById(db, userId));
      // El cliente pudo llegar acá con el token acotado del login: se le
      // entrega un access token completo para continuar con sesión plena.
      const accessToken = await issueAccessTokenForUserId(userId);
      return jsonResponse({
        status: 'verified',
        message: '¡Email verificado correctamente!',
        mail_verified_at: result.mailVerifiedAt ?? user?.mail_verified_at?.toISOString() ?? null,
        ...(accessToken ? { accessToken } : {}),
      });
    }

    if (result.status === 'invalid') {
      const remaining = result.attemptsRemaining ?? 0;
      return jsonResponse(
        {
          error:
            remaining > 0
              ? `Código incorrecto. Te quedan ${remaining} intento${remaining === 1 ? '' : 's'}.`
              : 'Código incorrecto. Verificá e intentá de nuevo.',
          code: 'INVALID_CODE',
          attempts_remaining: remaining,
          max_attempts: config.maxAttempts,
        },
        422,
      );
    }

    if (result.status === 'too_many_attempts') {
      return jsonResponse(
        {
          error: 'Demasiados intentos incorrectos. El código fue invalidado. Solicitá uno nuevo.',
          code: 'TOO_MANY_ATTEMPTS',
          attempts_remaining: 0,
          max_attempts: config.maxAttempts,
        },
        429,
      );
    }

    if (result.status === 'mail_sync_failed') {
      return jsonResponse(
        {
          error:
            'El mail de tu cuenta no coincide con el del código. Guardá el perfil e pedí un código nuevo.',
          code: 'MAIL_OUT_OF_SYNC',
        },
        409,
      );
    }

    if (result.status === 'expired') {
      return jsonResponse(
        { error: 'El código expiró. Solicitá uno nuevo.', code: 'CODE_EXPIRED' },
        422,
      );
    }

    return jsonResponse(
      {
        error: 'No hay un código de verificación pendiente. Solicitá uno primero.',
        code: 'NO_PENDING_CODE',
      },
      422,
    );
  } catch (error) {
    if (error instanceof AuthError) {
      return jsonResponse({ error: 'Invalid token', code: 'INVALID_CREDENTIALS' }, 401);
    }
    if (error instanceof ConfigError) {
      return errorResponse(503, error.message);
    }
    console.error('[verify-email-confirm]', error);
    return errorResponse(500, 'Internal server error');
  }
});
