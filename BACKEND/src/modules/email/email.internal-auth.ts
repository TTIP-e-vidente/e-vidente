import { Request } from 'express';
import { emailConfig } from './email.config';

export function isAuthorizedInternalRequest(request: Request): boolean {
  const providedSecret = request.header('x-job-secret') ?? '';
  return Boolean(emailConfig.cronSecret) && providedSecret === emailConfig.cronSecret;
}
