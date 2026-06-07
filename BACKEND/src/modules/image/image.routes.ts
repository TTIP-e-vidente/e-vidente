import { Router } from 'express';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';
import { getAvatarController, uploadAvatarController } from './image.controller';

export const imageRouter = Router();

imageRouter.post('/me/avatar', authenticateToken, uploadAvatarController);
imageRouter.get('/me/avatar', authenticateToken, getAvatarController);
