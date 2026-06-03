import { Request, Response } from 'express';
import {
  getPlayerMe,
  getPlayerProgress,
  PlayerError,
  saveAuthenticatedProgress
} from './player.service';
import { sendError } from '../../shared/http/send_error';

function getAuthenticatedUserId(request: Request): string {
  const userId = request.user?.id;
  if (!userId) {
    throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
  }

  return userId;
}

export async function getPlayerMeController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    response.json(await getPlayerMe(getAuthenticatedUserId(request)));
  } catch (error) {
    sendError(response, error);
  }
}

export async function getPlayerProgressController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    response.json(await getPlayerProgress(getAuthenticatedUserId(request)));
  } catch (error) {
    sendError(response, error);
  }
}

export async function postPlayerProgressController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const result = await saveAuthenticatedProgress({
      userId: getAuthenticatedUserId(request),
      ...(request.body ?? {})
    });
    response.status(201).json(result);
  } catch (error) {
    sendError(response, error);
  }
}
