import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import {
  getDevProgressByUsername,
  getProgresoRestriccion,
  saveAuthenticatedProgress,
  saveDevProgress
} from './progreso-restriccion.service';

export async function getProgresoRestriccionController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const response = await getProgresoRestriccion(userId);
    sendResponse(res, 200, response);
  } catch (error) {
    sendError(res, error);
  }
}

export async function postProgresoRestriccionController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const input = { ...req.body, userId };
    const response = await saveAuthenticatedProgress(input);
    sendResponse(res, 201, response);
  } catch (error) {
    sendError(res, error);
  }
}

export async function postDevProgresoRestriccionController(req: Request, res: Response): Promise<void> {
  try {
    const response = await saveDevProgress(req.body);
    sendResponse(res, 201, response);
  } catch (error) {
    sendError(res, error);
  }
}

export async function getDevProgresoRestriccionController(req: Request, res: Response): Promise<void> {
  try {
    const username = req.params.username as string;
    if (!username) {
      res.status(400).json({ error: 'username is required' });
      return;
    }

    const response = await getDevProgressByUsername(username);
    if (!response) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    sendResponse(res, 200, response);
  } catch (error) {
    sendError(res, error);
  }
}
