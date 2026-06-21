import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import {
  buildTemplatePreview,
  listEmailDeliveries,
  listEmailTemplates,
  parseDeliveryStatus,
  parseTemplateKey
} from './email.service';

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

export async function listEmailDeliveriesController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const deliveries = await listEmailDeliveries({
      userId: typeof request.query.user_id === 'string' ? request.query.user_id : undefined,
      templateKey: parseTemplateKey(request.query.template_key),
      status: parseDeliveryStatus(request.query.status),
      limit: parseLimit(request.query.limit)
    });

    sendResponse(response, 200, {
      count: deliveries.length,
      deliveries: deliveries.map((delivery) => ({
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
      }))
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
