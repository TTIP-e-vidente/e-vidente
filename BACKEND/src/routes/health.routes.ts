import { Router } from 'express';
import { getDatabaseHealth, getHealth } from '../controllers/health.controller';

export const healthRouter = Router();

healthRouter.get('/', getHealth);
healthRouter.get('/db', getDatabaseHealth);
