import { Router } from 'express';
import { getCronHealth, getDatabaseHealth, getEmailHealth, getHealth, getReadiness } from './health.controller';

export const healthRouter = Router();

healthRouter.get('/', getHealth);
healthRouter.get('/db', getDatabaseHealth);
healthRouter.get('/email', getEmailHealth);
healthRouter.get('/cron', getCronHealth);
healthRouter.get('/ready', getReadiness);
