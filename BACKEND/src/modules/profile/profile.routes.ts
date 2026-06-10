import { Router } from 'express';
import { getPlayerMeController, patchPlayerMeController } from './profile.controller';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';

export const profileRouter = Router();

// Endpoint mantenido en la misma ruta por compatibilidad
profileRouter.get('/me', authenticateToken, getPlayerMeController);
profileRouter.patch('/me', authenticateToken, patchPlayerMeController);
