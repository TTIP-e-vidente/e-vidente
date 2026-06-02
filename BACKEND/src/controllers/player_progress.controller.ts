import { Request, Response } from 'express';
import {
  getPlayerProgressByUsername,
  savePlayerProgress
} from '../services/player_progress.service';

export async function postPlayerProgress(request: Request, response: Response): Promise<void> {
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
    response.status(400).json({ error: 'username es requerido' });
    return;
  }
  if (typeof requestedRestriction !== 'string' || requestedRestriction.trim().length === 0) {
    response.status(400).json({ error: 'restriction es requerido' });
    return;
  }
  if (typeof expToAdd !== 'number' || !Number.isFinite(expToAdd)) {
    response.status(400).json({ error: 'expToAdd debe ser numerico' });
    return;
  }

  try {
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
    response.status(400).json({
      error: error instanceof Error ? error.message : 'No se pudo guardar progreso'
    });
  }
}

export async function getPlayerProgress(request: Request, response: Response): Promise<void> {
  const rawUsername = request.params.username;
  const username = typeof rawUsername === 'string' ? rawUsername.trim() : '';
  if (!username) {
    response.status(400).json({ error: 'username es requerido' });
    return;
  }

  const result = await getPlayerProgressByUsername(username);
  if (!result) {
    response.status(404).json({ error: 'jugador no encontrado' });
    return;
  }

  response.json(result);
}
