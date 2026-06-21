import { Router } from 'express';
import { getDatabaseHealth, getEmailHealth, getHealth } from './health.controller';

export const healthRouter = Router();

healthRouter.get('/', getHealth);
healthRouter.get('/db', getDatabaseHealth);
healthRouter.get('/email', getEmailHealth);
