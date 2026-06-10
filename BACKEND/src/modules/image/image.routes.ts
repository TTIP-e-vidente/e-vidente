import { Router } from 'express';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';
import { deleteAvatarController, getAvatarController, uploadAvatarController } from './image.controller';

export const imageRouter = Router();

imageRouter.post('/me/avatar', authenticateToken, uploadAvatarController);
imageRouter.get('/me/avatar', authenticateToken, getAvatarController);
imageRouter.delete('/me/avatar', authenticateToken, deleteAvatarController);
