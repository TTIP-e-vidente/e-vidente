import { Router } from 'express';
import {
  getPlayerProgress,
  postPlayerProgress
} from '../controllers/player_progress.controller';

export const playerProgressRouter = Router();

playerProgressRouter.post('/', postPlayerProgress);
playerProgressRouter.get('/:username', getPlayerProgress);
