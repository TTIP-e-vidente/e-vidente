import { Router } from 'express';
import {
  getPlayerMeController,
  getPlayerProgressController,
  postPlayerProgressController
} from './player.controller';
import { authenticateToken } from '../auth/authenticate_token';

export const playerRouter = Router();

playerRouter.use(authenticateToken);
playerRouter.get('/me', getPlayerMeController);
playerRouter.get('/me/progress', getPlayerProgressController);
playerRouter.post('/me/progress', postPlayerProgressController);
