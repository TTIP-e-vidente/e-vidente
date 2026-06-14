import { Router } from 'express';
import {
  listEmailDeliveriesController,
  listEmailTemplatesController,
  previewEmailTemplateController
} from './email.controller';

export const devEmailRouter = Router();

devEmailRouter.get('/deliveries', listEmailDeliveriesController);
devEmailRouter.get('/templates', listEmailTemplatesController);
devEmailRouter.get('/preview', previewEmailTemplateController);
