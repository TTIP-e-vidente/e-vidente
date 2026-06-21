import { Router } from 'express';
import { getPlayerMeController, patchPlayerMeController } from './profile.controller';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';
import {
  confirmVerificationController,
  getEmailStatusController,
  requestVerificationController
} from '../email/email.verification.controller';

export const profileRouter = Router();

// Endpoint mantenido en la misma ruta por compatibilidad
profileRouter.get('/me', authenticateToken, getPlayerMeController);
profileRouter.patch('/me', authenticateToken, patchPlayerMeController);
profileRouter.get('/me/email-status', authenticateToken, getEmailStatusController);

// Verificación de email por código OTP
profileRouter.post('/verify-email/request', authenticateToken, requestVerificationController);
profileRouter.post('/verify-email/confirm', authenticateToken, confirmVerificationController);
