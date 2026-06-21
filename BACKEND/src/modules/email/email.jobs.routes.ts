import { Router, Request, Response } from 'express';
import { emailConfig } from './email.config';
import {
  runOutboundEmailJob,
  runRetryFailedEmailJob,
  runStreakEmailJob
} from './email.service';
import { handleBrevoWebhookEvents, BrevoWebhookEvent } from './email.webhook.service';
import { isAuthorizedInternalRequest } from './email.internal-auth';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { refreshAllLeaderboards } from '../leaderboard/leaderboard.service';

export const internalJobsRouter = Router();

function isAuthorizedJob(request: Request): boolean {
  return isAuthorizedInternalRequest(request);
}

internalJobsRouter.post('/streak-emails', async (request: Request, response: Response) => {
  try {
    if (!isAuthorizedJob(request)) {
      sendResponse(response, 401, { error: 'Unauthorized job secret' });
      return;
    }

    const result = await runStreakEmailJob();
    sendResponse(response, 200, result);
  } catch (error) {
    sendError(response, error);
  }
});

internalJobsRouter.post('/retry-failed-emails', async (request: Request, response: Response) => {
  try {
    if (!isAuthorizedJob(request)) {
      sendResponse(response, 401, { error: 'Unauthorized job secret' });
      return;
    }

    const result = await runRetryFailedEmailJob();
    sendResponse(response, 200, result);
  } catch (error) {
    sendError(response, error);
  }
});

internalJobsRouter.post('/outbound-emails', async (request: Request, response: Response) => {
  try {
    if (!isAuthorizedJob(request)) {
      sendResponse(response, 401, { error: 'Unauthorized job secret' });
      return;
    }

    const result = await runOutboundEmailJob();
    sendResponse(response, 200, result);
  } catch (error) {
    sendError(response, error);
  }
});

internalJobsRouter.post('/brevo-webhook', async (request: Request, response: Response) => {
  try {
    const providedSecret = request.header('x-brevo-webhook-secret') ?? '';
    if (!emailConfig.webhookSecret || providedSecret !== emailConfig.webhookSecret) {
      sendResponse(response, 401, { error: 'Unauthorized webhook secret' });
      return;
    }

    const body = request.body;
    const events: BrevoWebhookEvent[] = Array.isArray(body) ? body : [body as BrevoWebhookEvent];
    const result = await handleBrevoWebhookEvents(events);
    sendResponse(response, 200, result);
  } catch (error) {
    sendError(response, error);
  }
});

// ─── Leaderboard refresh ──────────────────────────────────────────────────────

internalJobsRouter.post('/refresh-leaderboard', async (request: Request, response: Response) => {
  try {
    if (!isAuthorizedJob(request)) {
      sendResponse(response, 401, { error: 'Unauthorized job secret' });
      return;
    }

    const startMs = Date.now();
    const results = await refreshAllLeaderboards();
    sendResponse(response, 200, {
      totalDurationMs: Date.now() - startMs,
      results
    });
  } catch (error) {
    sendError(response, error);
  }
});
