/**
 * PROGRESO_RESTRICCION del MER.
 *
 * Responsabilidad:
 * - Guardar y consultar progreso por restricción alimentaria.
 * - Orquestar HISTORY_GAME y GAME al finalizar una partida.
 * - Mantener idempotencia mediante clientRunId.
 */
import { pool } from '../../config/database';
import { AppError } from '../../shared/errors/app_error';
import { normalizeRestrictionInput } from '../../config/restrictions';
import {
  isNonEmptyString,
  parseNumberOrDefault
} from '../../shared/validation/validators';
import {
  ProgresoRestriccionResponse,
  SaveProgresoRestriccionResponse,
  toPublicCompletedNode,
  toPublicProgresoRestriccion
} from './progreso-restriccion.mapper';
import { SaveAuthenticatedProgressInput, SaveDevProgressInput } from './progreso-restriccion.types';

import * as userRepository from '../user/user.repository';
import * as profileRepository from '../profile/profile.repository';
import * as streakRepository from '../streak/streak.repository';
import * as gameRepository from '../game/game.repository';
import * as historyGameRepository from '../history-game/history-game.repository';
import * as progresoRestriccionRepository from './progreso-restriccion.repository';
import { toPublicProfile } from '../profile/profile.mapper';
import { toPublicStreak } from '../streak/streak.mapper';
import { toPublicGame } from '../game/game.mapper';
import { triggerLeaderboardRefresh } from '../leaderboard/leaderboard.service';

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

function optionalClientRunId(value: unknown): string | null {
  const clientRunId = optionalText(value);
  if (clientRunId === null) return null;
  if (clientRunId.length > 120) {
    throw new PlayerError(400, 'VALIDATION_ERROR', 'clientRunId debe tener hasta 120 caracteres');
  }
  return clientRunId;
}

function numberOrDefault(value: unknown, defaultValue: number): number {
  const parsed = parseNumberOrDefault(value, defaultValue);
  if (Number.isNaN(parsed)) {
    throw new PlayerError(400, 'VALIDATION_ERROR', 'valor numerico invalido');
  }
  return parsed;
}

function normalizeRestriction(value: unknown): string {
  const raw = requiredText(value, 'restriction');
  const restriction = normalizeRestrictionInput(raw);
  if (!restriction) {
    throw new PlayerError(400, 'VALIDATION_ERROR', `restriction invalida: ${raw}`);
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

function optionalCalendarDay(value: unknown, fieldName: string): string | null {
  if (value === undefined || value === null) return null;
  const s = optionalText(value);
  if (s === null) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s) || isNaN(Date.parse(`${s}T00:00:00.000Z`))) {
    throw new PlayerError(400, 'VALIDATION_ERROR', `${fieldName} debe ser YYYY-MM-DD`);
  }
  return s;
}

export async function getProgresoRestriccion(userId: string): Promise<ProgresoRestriccionResponse> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await userRepository.findPublicUserById(userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await profileRepository.ensureProfile(client, userId);
    let streak = await streakRepository.getStreakByUserId(client, userId);
    if (!streak) {
      streak = await streakRepository.ensureStreak(client, userId, profile.id);
    }
    const progress = await progresoRestriccionRepository.listProgressByUserId(client, userId);
    const completedNodes = await progresoRestriccionRepository.listCompletedNodesByUserId(client, userId);
    const recentGames = await gameRepository.listRecentGamesByUserId(client, userId);
    await client.query('COMMIT');

    return {
      user,
      profile: toPublicProfile(profile),
      streak: toPublicStreak(streak),
      progress: progress.map(toPublicProgresoRestriccion),
      completedNodes: completedNodes.map(toPublicCompletedNode),
      recentGames: recentGames.map(toPublicGame)
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function saveAuthenticatedProgress(
  input: SaveAuthenticatedProgressInput,
  options: { includeSummary?: boolean } = {}
): Promise<SaveProgresoRestriccionResponse> {
  // El batch lo desactiva: calcular el summary (3 listados) por cada ítem es trabajo
  // que el controller batch descarta; ahí se arma un único summary al final.
  const includeSummary = options.includeSummary !== false;
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
  const localDay = optionalCalendarDay(input.localDay, 'localDay');
  const clientRunId = optionalClientRunId(input.clientRunId);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Lock por usuario: serializa saves concurrentes del mismo user (ej: dos sesiones abiertas).
    await client.query(`SELECT pg_advisory_xact_lock(hashtext($1)::bigint)`, [input.userId]);
    const user = await userRepository.findPublicUserById(input.userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const baseProfile = await profileRepository.ensureProfile(client, input.userId, restriction);
    let streak = await streakRepository.getStreakByUserId(client, input.userId);
    if (!streak) {
      streak = await streakRepository.ensureStreak(client, input.userId, baseProfile.id);
    }
    const baseProgress = await progresoRestriccionRepository.upsertProgress(
      client,
      input.userId,
      baseProfile.id,
      restriction,
      0,
      0
    );

    if (clientRunId) {
      const existingSession = await gameRepository.findGameByClientRunId(
        client,
        baseProgress.id,
        clientRunId
      );
      if (existingSession) {
        const duplicateSummary = includeSummary
          ? {
              user,
              profile: toPublicProfile(baseProfile),
              streak: toPublicStreak(streak),
              progress: (
                await progresoRestriccionRepository.listProgressByUserId(client, input.userId)
              ).map(toPublicProgresoRestriccion),
              completedNodes: (
                await progresoRestriccionRepository.listCompletedNodesByUserId(client, input.userId)
              ).map(toPublicCompletedNode),
              recentGames: (
                await gameRepository.listRecentGamesByUserId(client, input.userId)
              ).map(toPublicGame)
            }
          : null;

        await client.query('COMMIT');

        return {
          user,
          profile: toPublicProfile(baseProfile),
          streak: toPublicStreak(streak),
          progress: toPublicProgresoRestriccion(baseProgress),
          game: toPublicGame(existingSession),
          completedNode: null,
          mapCompleted: false,
          summary: duplicateSummary,
          duplicate: true
        };
      }
    }

    const profile = await profileRepository.addProfileExp(client, input.userId, expToAdd, restriction);
    const progress = await progresoRestriccionRepository.upsertProgress(
      client,
      input.userId,
      profile.id,
      restriction,
      expToAdd,
      completed ? 1 : 0
    );
    const insertResult = await gameRepository.insertGame(client, {
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
      finishedAt,
      localDay,
      clientRunId
    });
    const game = insertResult.game;

    let completedNode = null;
    let mapCompleted = false;
    if (insertResult.wasNewlyCompleted && nodeId) {
      completedNode = await progresoRestriccionRepository.getCompletedNodeByProgressAndNode(
        client,
        progress.id,
        nodeId
      );
      const incrementResult = await progresoRestriccionRepository.incrementProgressCompletedNodes(
        client,
        progress.id
      );
      mapCompleted = incrementResult.map_completed;
    }

    if (completed) {
      streak = await streakRepository.registerStreakActivity(
        client,
        input.userId,
        profile.id,
        finishedAt
      );
    }

    const summary = includeSummary
      ? {
          user,
          profile: toPublicProfile(profile),
          streak: toPublicStreak(streak),
          progress: (
            await progresoRestriccionRepository.listProgressByUserId(client, input.userId)
          ).map(toPublicProgresoRestriccion),
          completedNodes: (
            await progresoRestriccionRepository.listCompletedNodesByUserId(client, input.userId)
          ).map(toPublicCompletedNode),
          recentGames: (
            await gameRepository.listRecentGamesByUserId(client, input.userId)
          ).map(toPublicGame)
        }
      : null;

    await client.query('COMMIT');

    // Trigger no bloqueante: el leaderboard se actualizará en background
    // (debounce de 5s, no afecta la latencia de este endpoint)
    if (expToAdd > 0 || completed) {
      triggerLeaderboardRefresh();
    }

    return {
      user,
      profile: toPublicProfile(profile),
      streak: toPublicStreak(streak),
      progress: toPublicProgresoRestriccion(progress),
      game: toPublicGame(game),
      completedNode: completedNode ? toPublicCompletedNode(completedNode) : null,
      mapCompleted,
      summary
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function saveDevProgress(input: SaveDevProgressInput): Promise<SaveProgresoRestriccionResponse> {
  const client = await pool.connect();
  let userId: string;
  try {
    await client.query('BEGIN');
    const user = await userRepository.upsertDevUser(
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
    finishedAt: input.finishedAt,
    localDay: input.localDay,
    clientRunId: input.clientRunId
  });
}

export interface ResetAuthenticatedProgressInput {
  userId: string;
  restriction?: unknown;
}

export async function resetAuthenticatedProgress(
  input: ResetAuthenticatedProgressInput
): Promise<ProgresoRestriccionResponse> {
  const restriction =
    input.restriction === undefined || input.restriction === null
      ? 'CELIAQUIA'
      : normalizeRestriction(input.restriction);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`SELECT pg_advisory_xact_lock(hashtext($1)::bigint)`, [input.userId]);
    const user = await userRepository.findPublicUserById(input.userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const progressRow = await progresoRestriccionRepository.findProgressByUserAndRestriction(
      client,
      input.userId,
      restriction
    );

    if (progressRow) {
      await historyGameRepository.deleteNodeHistoryByProgressId(client, progressRow.id);
      await progresoRestriccionRepository.resetProgressCounters(client, progressRow.id);
      // El leaderboard y el perfil leen profiles.exp_count (contador acumulado), no
      // progress_restrictions.total_exp. Tras poner total_exp en 0 hay que recalcular
      // exp_count desde las restricciones, o el XP viejo persistiría en ambos.
      await profileRepository.recomputeProfileExpFromRestrictions(client, input.userId);
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  // Refrescamos el snapshot/cache del leaderboard para que el ranking no siga
  // mostrando el XP previo al reset.
  triggerLeaderboardRefresh();

  return getProgresoRestriccion(input.userId);
}

export async function getDevProgressByUsername(username: string): Promise<ProgresoRestriccionResponse | null> {
  const client = await pool.connect();
  let userId: string | null = null;
  try {
    const user = await userRepository.findPublicUserByUsername(client, username);
    if (!user) {
      return null;
    }
    userId = user.id;
  } finally {
    client.release();
  }

  return userId ? getProgresoRestriccion(userId) : null;
}
