import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { getPlayerMe, updatePlayerMe } from './profile.service';

export async function getPlayerMeController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const response = await getPlayerMe(userId);
    sendResponse(res, 200, response);
  } catch (error) {
    sendError(res, error);
  }
}

export async function patchPlayerMeController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const response = await updatePlayerMe(userId, req.body);
    sendResponse(res, 200, response);
  } catch (error) {
    sendError(res, error);
  }
}
