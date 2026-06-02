import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send_error';
import {
  getPlayerProgressByUsername,
  savePlayerProgress
} from './player_progress.service';
import { PlayerError } from './player.service';

export async function postPlayerProgress(request: Request, response: Response): Promise<void> {
  try {
    const {
      username,
      name,
      restriction,
      restrictionType,
      expToAdd,
      nodeId,
      gameType,
      accuracy,
      completed,
      score
    } = request.body ?? {};
    const requestedRestriction = restriction ?? restrictionType;

    if (typeof username !== 'string' || username.trim().length === 0) {
      throw new PlayerError(400, 'VALIDATION_ERROR', 'username es requerido');
    }
    if (typeof requestedRestriction !== 'string' || requestedRestriction.trim().length === 0) {
      throw new PlayerError(400, 'VALIDATION_ERROR', 'restriction es requerido');
    }
    if (typeof expToAdd !== 'number' || !Number.isFinite(expToAdd)) {
      throw new PlayerError(400, 'VALIDATION_ERROR', 'expToAdd debe ser numerico');
    }

    const result = await savePlayerProgress({
      username: username.trim(),
      name: typeof name === 'string' && name.trim().length > 0 ? name.trim() : undefined,
      restriction: requestedRestriction.trim(),
      expToAdd,
      nodeId: typeof nodeId === 'string' && nodeId.trim().length > 0 ? nodeId.trim() : undefined,
      gameType: typeof gameType === 'string' && gameType.trim().length > 0 ? gameType.trim() : undefined,
      accuracy: typeof accuracy === 'number' && Number.isFinite(accuracy) ? accuracy : undefined,
      completed: typeof completed === 'boolean' ? completed : undefined,
      score: typeof score === 'number' && Number.isFinite(score) ? score : undefined
    });

    response.status(201).json(result);
  } catch (error) {
    sendError(response, error);
  }
}

export async function getPlayerProgress(request: Request, response: Response): Promise<void> {
  try {
    const rawUsername = request.params.username;
    const username = typeof rawUsername === 'string' ? rawUsername.trim() : '';
    if (!username) {
      throw new PlayerError(400, 'VALIDATION_ERROR', 'username es requerido');
    }

    const result = await getPlayerProgressByUsername(username);
    if (!result) {
      throw new PlayerError(404, 'PLAYER_NOT_FOUND', 'jugador no encontrado');
    }

    response.json(result);
  } catch (error) {
    sendError(response, error);
  }
}
