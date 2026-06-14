import { Router, Request, Response } from 'express';
import { emailConfig } from './email.config';
import { runStreakEmailJob } from './email.service';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';

export const internalJobsRouter = Router();

internalJobsRouter.post('/streak-emails', async (request: Request, response: Response) => {
  try {
    const providedSecret = request.header('x-job-secret') ?? '';
    if (!emailConfig.cronSecret || providedSecret !== emailConfig.cronSecret) {
      sendResponse(response, 401, { error: 'Unauthorized job secret' });
      return;
    }

    const result = await runStreakEmailJob();
    sendResponse(response, 200, result);
  } catch (error) {
    sendError(response, error);
  }
});
