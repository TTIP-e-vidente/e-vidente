import { Router } from 'express';
import express from 'express';
import {
  buildVerificationCopyExpiredPageHtml,
  buildVerificationCopyPageHtml,
  parseVerificationCopyToken
} from './email.verification-copy';
import { resolveEmailAssetsDirectory } from './templates/email-assets';

export const publicEmailRouter = Router();

const assetsDir = resolveEmailAssetsDirectory();

publicEmailRouter.use('/assets', express.static(assetsDir));

publicEmailRouter.get('/verification-copy/:token', (req, res) => {
  const token = typeof req.params.token === 'string' ? req.params.token : '';
  const parsed = parseVerificationCopyToken(token);

  if (!parsed) {
    res.status(410).type('html').send(buildVerificationCopyExpiredPageHtml());
    return;
  }

  res.status(200).type('html').send(buildVerificationCopyPageHtml(parsed.code));
});
