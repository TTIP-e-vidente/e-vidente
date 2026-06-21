import { Router, Request, Response, NextFunction } from 'express';
import { sendResponse } from '../../shared/http/send-response';
import { isAuthorizedInternalRequest } from './email.internal-auth';
import { listInternalEmailDeliveriesController } from './email.controller';

export const internalEmailRouter = Router();

function requireInternalSecret(request: Request, response: Response, next: NextFunction): void {
  if (!isAuthorizedInternalRequest(request)) {
    sendResponse(response, 401, { error: 'Unauthorized job secret' });
    return;
  }
  next();
}

internalEmailRouter.use(requireInternalSecret);
internalEmailRouter.get('/deliveries', listInternalEmailDeliveriesController);
