import { Router } from 'express';
import { getPlayerMeController, patchPlayerMeController } from './profile.controller';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';
import { authenticateVerificationToken } from '../../shared/middlewares/authenticate-verification-token';
import {
  confirmVerificationController,
  getEmailStatusController,
  requestVerificationController
} from '../email/email.verification.controller';

export const profileRouter = Router();

// Endpoint mantenido en la misma ruta por compatibilidad
profileRouter.get('/me', authenticateToken, getPlayerMeController);
profileRouter.patch('/me', authenticateToken, patchPlayerMeController);
profileRouter.get('/me/email-status', authenticateVerificationToken, getEmailStatusController);

// Verificación de email por código OTP.
// Aceptan el token acotado que devuelve el login cuando el mail no está verificado.
profileRouter.post('/verify-email/request', authenticateVerificationToken, requestVerificationController);
profileRouter.post('/verify-email/confirm', authenticateVerificationToken, confirmVerificationController);
