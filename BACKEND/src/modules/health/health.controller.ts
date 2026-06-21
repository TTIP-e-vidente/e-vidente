import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { emailConfig, isEmailDeliveryConfigured } from '../email/email.config';
import { getVerificationConfig } from '../email/email.verification.service';
import { getDbInfo } from './health.repository';

export function getHealth(_request: Request, response: Response): void {
  sendResponse(response, 200, { status: 'ok' });
}

export async function getDatabaseHealth(_request: Request, response: Response): Promise<void> {
  try {
    const info = await getDbInfo();
    sendResponse(response, 200, {
      status: 'ok',
      database: info.current_database,
      user: info.current_user
    });
  } catch (error) {
    sendError(response, error);
  }
}

export function getEmailHealth(_request: Request, response: Response): void {
  const deliveryConfigured = isEmailDeliveryConfigured();
  const verification = getVerificationConfig();

  sendResponse(response, 200, {
    status: deliveryConfigured ? 'ok' : 'degraded',
    email_enabled: emailConfig.enabled,
    delivery_configured: deliveryConfigured,
    brevo_api_key_present: emailConfig.brevoApiKey.length > 0,
    sender_email: emailConfig.senderEmail || null,
    sender_name: emailConfig.senderName,
    dev_code_in_logs:
      process.env.NODE_ENV === 'development' && emailConfig.enabled && !deliveryConfigured,
    verification: {
      expires_minutes: verification.expiresMinutes,
      cooldown_seconds: verification.cooldownSeconds,
      max_attempts: verification.maxAttempts
    },
    hints: deliveryConfigured
      ? []
      : [
          'Configurá BREVO_API_KEY y BREVO_SENDER_EMAIL en BACKEND/.env',
          'El remitente debe estar Verified en Brevo',
          'En desarrollo sin Brevo, el código OTP aparece en la consola del backend (dev_code)'
        ]
  });
}
