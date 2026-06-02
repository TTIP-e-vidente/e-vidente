import { pool } from '../config/database';
import * as playerRepository from '../repositories/player.repository';
import { AppError } from '../shared/errors/app_error';
import {
  isAllowedRestriction,
  isNonEmptyString,
  parseNumberOrDefault
} from '../shared/validation/validators';

export class PlayerError extends AppError {
  constructor(statusCode: number, code: string, message: string) {
    super(statusCode, code, message);
  }
}

export interface SaveAuthenticatedProgressInput {
  userId: string;
  restriction?: unknown;
  expToAdd?: unknown;
  nodeId?: unknown;
  gameType?: unknown;
  accuracy?: unknown;
  completed?: unknown;
  score?: unknown;
}

function requiredText(value: unknown, fieldName: string): string {
  if (!isNonEmptyString(value)) {
    throw new PlayerError(400, 'VALIDATION_ERROR', `${fieldName} es requerido`);
  }

  return value.trim();
}

function optionalText(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : null;
}

function numberOrDefault(value: unknown, defaultValue: number): number {
  const parsed = parseNumberOrDefault(value, defaultValue);
  if (Number.isNaN(parsed)) {
    throw new PlayerError(400, 'VALIDATION_ERROR', 'valor numerico invalido');
  }

  return parsed;
}

function normalizeRestriction(value: unknown): string {
  const restriction = requiredText(value, 'restriction').toUpperCase();
  if (!isAllowedRestriction(restriction)) {
    throw new PlayerError(400, 'VALIDATION_ERROR', `restriction invalida: ${restriction}`);
  }

  return restriction;
}

export async function getPlayerMe(userId: string): Promise<unknown> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await playerRepository.findPublicUserById(userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await playerRepository.ensureProfile(client, userId);
    const streak = await playerRepository.ensureStreak(client, userId);
    await client.query('COMMIT');

    return { user, profile, streak };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function getPlayerProgress(userId: string): Promise<unknown> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await playerRepository.findPublicUserById(userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await playerRepository.ensureProfile(client, userId);
    const streak = await playerRepository.ensureStreak(client, userId);
    const progress = await playerRepository.listProgressByUserId(client, userId);
    const completedNodes = await playerRepository.listCompletedNodesByUserId(client, userId);
    const unlockedContent = await playerRepository.listUnlockedContentByUserId(client, userId);
    const recentGameSessions = await playerRepository.listRecentGameSessionsByUserId(client, userId);
    await client.query('COMMIT');

    return {
      user,
      profile,
      streak,
      progress,
      completedNodes,
      unlockedContent,
      recentGameSessions
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function saveAuthenticatedProgress(
  input: SaveAuthenticatedProgressInput
): Promise<unknown> {
  const restriction = normalizeRestriction(input.restriction);
  const expToAdd = Math.max(0, Math.trunc(numberOrDefault(input.expToAdd, 0)));
  const nodeId = optionalText(input.nodeId);
  const gameType = optionalText(input.gameType) ?? 'unknown';
  const accuracyValue = input.accuracy === undefined ? null : numberOrDefault(input.accuracy, 0);
  if (accuracyValue !== null && (accuracyValue < 0 || accuracyValue > 100)) {
    throw new PlayerError(400, 'VALIDATION_ERROR', 'accuracy debe estar entre 0 y 100');
  }
  const completed = typeof input.completed === 'boolean' ? input.completed : true;
  if (input.completed !== undefined && typeof input.completed !== 'boolean') {
    throw new PlayerError(400, 'VALIDATION_ERROR', 'completed debe ser boolean');
  }
  const score = Math.trunc(numberOrDefault(input.score, 0));

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await playerRepository.findPublicUserById(input.userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await playerRepository.addProfileExp(client, input.userId, expToAdd, restriction);
    const streak = await playerRepository.ensureStreak(client, input.userId);
    const progress = await playerRepository.upsertProgress(
      client,
      input.userId,
      restriction,
      expToAdd,
      completed ? 1 : 0
    );
    const gameSession = await playerRepository.insertGameSession(client, {
      userId: input.userId,
      progressId: progress.id,
      gameType,
      nodeId,
      accuracy: accuracyValue,
      completed,
      score
    });

    let completedNode = null;
    if (completed && nodeId) {
      completedNode = await playerRepository.insertCompletedNodeIfMissing(client, {
        userId: input.userId,
        progressId: progress.id,
        nodeId,
        nodeType: gameType,
        score,
        accuracy: accuracyValue
      });

      if (completedNode) {
        await playerRepository.incrementProgressCompletedNodes(client, progress.id);
      }
    }

    const updatedProgress = await playerRepository.listProgressByUserId(client, input.userId);
    const completedNodes = await playerRepository.listCompletedNodesByUserId(client, input.userId);
    const unlockedContent = await playerRepository.listUnlockedContentByUserId(client, input.userId);
    const recentGameSessions = await playerRepository.listRecentGameSessionsByUserId(
      client,
      input.userId
    );

    await client.query('COMMIT');

    return {
      user,
      profile,
      streak,
      progress,
      gameSession,
      completedNode,
      summary: {
        user,
        profile,
        streak,
        progress: updatedProgress,
        completedNodes,
        unlockedContent,
        recentGameSessions
      }
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function saveDevProgress(input: {
  username: string;
  name?: string;
  restriction: string;
  expToAdd: number;
  nodeId?: string;
  gameType?: string;
  accuracy?: number;
  completed?: boolean;
  score?: number;
}): Promise<unknown> {
  const client = await pool.connect();
  let userId: string;
  try {
    await client.query('BEGIN');
    const user = await playerRepository.upsertDevUser(
      client,
      input.username,
      input.name ?? input.username
    );
    userId = user.id;
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  return saveAuthenticatedProgress({
    userId,
    restriction: input.restriction,
    expToAdd: input.expToAdd,
    nodeId: input.nodeId,
    gameType: input.gameType,
    accuracy: input.accuracy,
    completed: input.completed,
    score: input.score
  });
}

export async function getDevProgressByUsername(username: string): Promise<unknown | null> {
  const client = await pool.connect();
  let userId: string | null = null;
  try {
    const user = await playerRepository.findPublicUserByUsername(client, username);
    if (!user) {
      return null;
    }
    userId = user.id;
  } finally {
    client.release();
  }

  return userId ? getPlayerProgress(userId) : null;
}
