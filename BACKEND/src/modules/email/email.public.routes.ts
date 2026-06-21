import { Router } from 'express';
import path from 'path';
import express from 'express';
import {
  buildVerificationCopyExpiredPageHtml,
  buildVerificationCopyPageHtml,
  parseVerificationCopyToken
} from './email.verification-copy';

export const publicEmailRouter = Router();

const assetsDir = path.join(__dirname, '..', 'assets');

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
