import { pool } from '../../config/database';
import { AppError } from '../../shared/errors/app_error';
import {
  isAllowedRestriction,
  isNonEmptyString,
  parseNumberOrDefault
} from '../../shared/validation/validators';
import {
  PlayerMeResponse,
  PlayerProgressResponse,
  SavePlayerProgressResponse,
  toPublicCompletedNode,
  toPublicGameSession,
  toPublicPlayerProfile,
  toPublicPlayerProgress,
  toPublicPlayerStreak,
  toPublicUnlockedContent
} from './player.mapper';
import * as playerRepository from './player.repository';
import { SaveAuthenticatedProgressInput, SaveDevProgressInput } from './player.types';

export class PlayerError extends AppError {
  constructor(statusCode: number, code: string, message: string) {
    super(statusCode, code, message);
  }
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

function optionalNonNegativeInt(value: unknown, fieldName: string): number | null {
  if (value === undefined || value === null) return null;
  const parsed = parseNumberOrDefault(value, NaN);
  if (isNaN(parsed) || parsed < 0) {
    throw new PlayerError(400, 'VALIDATION_ERROR', `${fieldName} debe ser numero >= 0`);
  }
  return Math.trunc(parsed);
}

function optionalIsoDate(value: unknown, fieldName: string): string | null {
  if (value === undefined || value === null) return null;
  const s = optionalText(value);
  if (s !== null && isNaN(Date.parse(s))) {
    throw new PlayerError(400, 'VALIDATION_ERROR', `${fieldName} debe ser fecha ISO valida`);
  }
  return s;
}

export async function getPlayerMe(userId: string): Promise<PlayerMeResponse> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await playerRepository.findPublicUserById(userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await playerRepository.ensureProfile(client, userId);
    const streak = await playerRepository.ensureStreak(client, userId, profile.id);
    await client.query('COMMIT');

    return {
      user,
      profile: toPublicPlayerProfile(profile),
      streak: toPublicPlayerStreak(streak)
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function getPlayerProgress(userId: string): Promise<PlayerProgressResponse> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await playerRepository.findPublicUserById(userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await playerRepository.ensureProfile(client, userId);
    const streak = await playerRepository.ensureStreak(client, userId, profile.id);
    const progress = await playerRepository.listProgressByUserId(client, userId);
    const completedNodes = await playerRepository.listCompletedNodesByUserId(client, userId);
    const unlockedContent = await playerRepository.listUnlockedContentByUserId(client, userId);
    const recentGameSessions = await playerRepository.listRecentGameSessionsByUserId(client, userId);
    await client.query('COMMIT');

    return {
      user,
      profile: toPublicPlayerProfile(profile),
      streak: toPublicPlayerStreak(streak),
      progress: progress.map(toPublicPlayerProgress),
      completedNodes: completedNodes.map(toPublicCompletedNode),
      unlockedContent: unlockedContent.map(toPublicUnlockedContent),
      recentGameSessions: recentGameSessions.map(toPublicGameSession)
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
): Promise<SavePlayerProgressResponse> {
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
  const correctAnswers = optionalNonNegativeInt(input.correctAnswers, 'correctAnswers');
  const wrongAnswers = optionalNonNegativeInt(input.wrongAnswers, 'wrongAnswers');
  const durationSeconds = optionalNonNegativeInt(input.durationSeconds, 'durationSeconds');
  const finishedAt = optionalIsoDate(input.finishedAt, 'finishedAt');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await playerRepository.findPublicUserById(input.userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await playerRepository.addProfileExp(client, input.userId, expToAdd, restriction);
    const streak = await playerRepository.ensureStreak(client, input.userId, profile.id);
    const progress = await playerRepository.upsertProgress(
      client,
      input.userId,
      profile.id,
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
      score,
      correctAnswers,
      wrongAnswers,
      durationSeconds,
      finishedAt
    });

    let completedNode = null;
    if (completed && nodeId) {
      const upsertResult = await playerRepository.upsertCompletedNode(client, {
        userId: input.userId,
        progressId: progress.id,
        nodeId,
        nodeType: gameType,
        score,
        accuracy: accuracyValue
      });

      if (upsertResult.wasNew) {
        completedNode = upsertResult.node;
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
      profile: toPublicPlayerProfile(profile),
      streak: toPublicPlayerStreak(streak),
      progress: toPublicPlayerProgress(progress),
      gameSession: toPublicGameSession(gameSession),
      completedNode: completedNode ? toPublicCompletedNode(completedNode) : null,
      summary: {
        user,
        profile: toPublicPlayerProfile(profile),
        streak: toPublicPlayerStreak(streak),
        progress: updatedProgress.map(toPublicPlayerProgress),
        completedNodes: completedNodes.map(toPublicCompletedNode),
        unlockedContent: unlockedContent.map(toPublicUnlockedContent),
        recentGameSessions: recentGameSessions.map(toPublicGameSession)
      }
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function saveDevProgress(input: SaveDevProgressInput): Promise<SavePlayerProgressResponse> {
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
    score: input.score,
    correctAnswers: input.correctAnswers,
    wrongAnswers: input.wrongAnswers,
    durationSeconds: input.durationSeconds,
    finishedAt: input.finishedAt
  });
}

export async function getDevProgressByUsername(username: string): Promise<PlayerProgressResponse | null> {
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
