import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import * as userRepository from '../user/user.repository';
import {
  buildTemplatePreview,
  listEmailDeliveries,
  listEmailTemplates,
  parseDeliveryStatus,
  parseTemplateKey
} from './email.service';
import * as emailRepository from './email.repository';
import { getEmailVerificationStatus } from './email.verification.service';
import { EmailDeliveryRow } from './email.types';

function parseLimit(value: unknown): number | undefined {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return undefined;
  }
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    return undefined;
  }
  return parsed;
}

function parseStreakCount(value: unknown): number | undefined {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return undefined;
  }
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    return undefined;
  }
  return parsed;
}

function pickQueryParam(request: Request, keys: string[]): string | undefined {
  for (const key of keys) {
    const value = request.query[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return undefined;
}

function mapDeliveryRow(delivery: EmailDeliveryRow) {
  return {
    id: delivery.id,
    user_id: delivery.user_id,
    username: delivery.username,
    user_mail: delivery.user_mail,
    template_key: delivery.template_key,
    dedupe_key: delivery.dedupe_key,
    recipient_email: delivery.recipient_email,
    subject: delivery.subject,
    status: delivery.status,
    provider_message_id: delivery.provider_message_id,
    error_message: delivery.error_message,
    attempt_count: delivery.attempt_count,
    created_at: delivery.created_at,
    sent_at: delivery.sent_at,
    failed_at: delivery.failed_at
  };
}

async function resolveUserIdFromQuery(
  request: Request
): Promise<{ userId?: string; lookupError?: string }> {
  const directUserId = pickQueryParam(request, ['userId', 'user_id']);
  if (directUserId) {
    return { userId: directUserId };
  }

  const username = pickQueryParam(request, ['username']);
  if (username) {
    const userId = await userRepository.findUserIdByUsername(username);
    if (!userId) {
      return { lookupError: `Usuario no encontrado: ${username}` };
    }
    return { userId };
  }

  const mail = pickQueryParam(request, ['mail', 'email']);
  if (mail) {
    const userId = await userRepository.findUserIdByMail(mail);
    if (!userId) {
      return { lookupError: `No hay usuario con mail: ${mail}` };
    }
    return { userId };
  }

  return {};
}

function buildDeliveryFilters(request: Request, userId?: string) {
  return {
    userId,
    templateKey: parseTemplateKey(request.query.template_key),
    status: parseDeliveryStatus(request.query.status),
    limit: parseLimit(request.query.limit)
  };
}

export async function listEmailDeliveriesController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const resolved = await resolveUserIdFromQuery(request);
    if (resolved.lookupError) {
      sendResponse(response, 404, { error: resolved.lookupError });
      return;
    }

    const deliveries = await listEmailDeliveries(buildDeliveryFilters(request, resolved.userId));

    sendResponse(response, 200, {
      count: deliveries.length,
      deliveries: deliveries.map(mapDeliveryRow)
    });
  } catch (error) {
    sendError(response, error);
  }
}

export async function listInternalEmailDeliveriesController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const resolved = await resolveUserIdFromQuery(request);
    if (resolved.lookupError) {
      sendResponse(response, 404, { error: resolved.lookupError });
      return;
    }

    const filters = buildDeliveryFilters(request, resolved.userId);
    const [deliveries, summary, user, verificationStatus] = await Promise.all([
      listEmailDeliveries(filters),
      emailRepository.summarizeDeliveries({
        userId: resolved.userId,
        templateKey: filters.templateKey
      }),
      resolved.userId ? userRepository.findPublicUserById(resolved.userId) : Promise.resolve(null),
      resolved.userId ? getEmailVerificationStatus(resolved.userId) : Promise.resolve(null)
    ]);

    sendResponse(response, 200, {
      lookup: user
        ? {
            user_id: user.id,
            username: user.username,
            mail: user.mail,
            mail_verified_at: user.mail_verified_at ? user.mail_verified_at.toISOString() : null,
            email_notifications_enabled: user.email_notifications_enabled
          }
        : null,
      summary,
      verification: verificationStatus
        ? {
            ...verificationStatus.verification,
            last_verification_delivery: verificationStatus.last_verification_delivery,
            delivery_configured: verificationStatus.delivery_configured,
            dev_code_in_logs: verificationStatus.dev_code_in_logs
          }
        : null,
      count: deliveries.length,
      deliveries: deliveries.map(mapDeliveryRow),
      hints: [
        'Filtrá por userId, username o mail. Ej: /internal/email/deliveries?mail=agus@mail.com',
        'Sin webhook Brevo (ngrok), los bounces no se actualizan solos; igual ves sent/failed del backend.',
        'OTP reciente: template_key=email_verification. Welcome: template_key=welcome.',
        'Header requerido: X-Job-Secret (mismo valor que EMAIL_CRON_SECRET).'
      ]
    });
  } catch (error) {
    sendError(response, error);
  }
}

export async function listEmailTemplatesController(
  _request: Request,
  response: Response
): Promise<void> {
  try {
    const templates = listEmailTemplates();
    sendResponse(response, 200, {
      count: templates.length,
      templates
    });
  } catch (error) {
    sendError(response, error);
  }
}

export async function previewEmailTemplateController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const templateKey = parseTemplateKey(request.query.template_key);
    if (!templateKey) {
      sendResponse(response, 400, {
        error: 'template_key is required (welcome | streak_at_risk | streak_lost | email_verification | mail_changed)'
      });
      return;
    }

    const preview = buildTemplatePreview(templateKey, {
      name: typeof request.query.name === 'string' ? request.query.name : undefined,
      mail: typeof request.query.mail === 'string' ? request.query.mail : undefined,
      streak_count: parseStreakCount(request.query.streak_count)
    });

    sendResponse(response, 200, {
      template_key: templateKey,
      preview
    });
  } catch (error) {
    sendError(response, error);
  }
}
