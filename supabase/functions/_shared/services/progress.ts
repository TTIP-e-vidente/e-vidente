import { withTransaction } from '../db.ts';
import { normalizeRestrictionInput } from '../restrictions.ts';
import { PlayerError } from '../player-errors.ts';
import { isNonEmptyString, parseNumberOrDefault } from '../validators.ts';
import * as gameRepository from '../repositories/game.ts';
import * as historyGameRepository from '../repositories/history-game.ts';
import * as profileRepository from '../repositories/profile.ts';
import * as progressRepository from '../repositories/progress.ts';
import * as streakRepository from '../repositories/streak.ts';
import * as userRepository from '../repositories/user.ts';
import {
  toPublicCompletedNode,
  toPublicGame,
  toPublicProfile,
  toPublicProgresoRestriccion,
  toPublicStreak,
  type ProgresoRestriccionResponse,
  type SaveProgresoRestriccionResponse,
} from '../mappers/player.ts';
import type { SaveAuthenticatedProgressInput } from '../types/player.ts';
import { triggerLeaderboardRefreshAfterProgress } from './leaderboard-refresh.ts';

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
  return await withTransaction(async (client) => {
    const user = await userRepository.findPublicUserByIdOnClient(client, userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await profileRepository.ensureProfile(client, userId);
    let streak = await streakRepository.getStreakByUserId(client, userId);
    if (!streak) {
      streak = await streakRepository.ensureStreak(client, userId, profile.id);
    }
    const progress = await progressRepository.listProgressByUserId(client, userId);
    const completedNodes = await progressRepository.listCompletedNodesByUserId(client, userId);
    const recentGames = await gameRepository.listRecentGamesByUserId(client, userId);

    return {
      user,
      profile: toPublicProfile(profile),
      streak: toPublicStreak(streak),
      progress: progress.map(toPublicProgresoRestriccion),
      completedNodes: completedNodes.map(toPublicCompletedNode),
      recentGames: recentGames.map(toPublicGame),
    };
  });
}

export async function saveAuthenticatedProgress(
  input: SaveAuthenticatedProgressInput,
  options: { includeSummary?: boolean } = {},
): Promise<SaveProgresoRestriccionResponse> {
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
  const shouldRefreshLeaderboard = expToAdd > 0 || completed;
  const saveFlags = { applied: false };

  const response = await withTransaction(async (client) => {
    await client.queryObject(`SELECT pg_advisory_xact_lock(hashtext($1)::bigint)`, [input.userId]);
    const user = await userRepository.findPublicUserByIdOnClient(client, input.userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const baseProfile = await profileRepository.ensureProfile(client, input.userId, restriction);
    let streak = await streakRepository.getStreakByUserId(client, input.userId);
    if (!streak) {
      streak = await streakRepository.ensureStreak(client, input.userId, baseProfile.id);
    }
    const baseProgress = await progressRepository.upsertProgress(
      client,
      input.userId,
      baseProfile.id,
      restriction,
      0,
      0,
    );

    if (clientRunId) {
      const existingSession = await gameRepository.findGameByClientRunId(
        client,
        baseProgress.id,
        clientRunId,
      );
      if (existingSession) {
        const duplicateSummary = includeSummary
          ? {
            user,
            profile: toPublicProfile(baseProfile),
            streak: toPublicStreak(streak),
            progress: (await progressRepository.listProgressByUserId(client, input.userId)).map(
              toPublicProgresoRestriccion,
            ),
            completedNodes: (await progressRepository.listCompletedNodesByUserId(client, input.userId))
              .map(toPublicCompletedNode),
            recentGames: (await gameRepository.listRecentGamesByUserId(client, input.userId)).map(
              toPublicGame,
            ),
          }
          : null;

        return {
          user,
          profile: toPublicProfile(baseProfile),
          streak: toPublicStreak(streak),
          progress: toPublicProgresoRestriccion(baseProgress),
          game: toPublicGame(existingSession),
          completedNode: null,
          mapCompleted: false,
          summary: duplicateSummary,
          duplicate: true,
        };
      }
    }

    saveFlags.applied = true;
    const profile = await profileRepository.addProfileExp(client, input.userId, expToAdd, restriction);
    const progress = await progressRepository.upsertProgress(
      client,
      input.userId,
      profile.id,
      restriction,
      expToAdd,
      completed ? 1 : 0,
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
      clientRunId,
    });
    const game = insertResult.game;

    let completedNode = null;
    let mapCompleted = false;
    if (insertResult.wasNewlyCompleted && nodeId) {
      completedNode = await progressRepository.getCompletedNodeByProgressAndNode(
        client,
        progress.id,
        nodeId,
      );
      const incrementResult = await progressRepository.incrementProgressCompletedNodes(
        client,
        progress.id,
      );
      mapCompleted = incrementResult.map_completed;
    }

    if (completed) {
      streak = await streakRepository.registerStreakActivity(
        client,
        input.userId,
        profile.id,
        finishedAt,
      );
    }

    const summary = includeSummary
      ? {
        user,
        profile: toPublicProfile(profile),
        streak: toPublicStreak(streak),
        progress: (await progressRepository.listProgressByUserId(client, input.userId)).map(
          toPublicProgresoRestriccion,
        ),
        completedNodes: (await progressRepository.listCompletedNodesByUserId(client, input.userId))
          .map(toPublicCompletedNode),
        recentGames: (await gameRepository.listRecentGamesByUserId(client, input.userId)).map(
          toPublicGame,
        ),
      }
      : null;

    return {
      user,
      profile: toPublicProfile(profile),
      streak: toPublicStreak(streak),
      progress: toPublicProgresoRestriccion(progress),
      game: toPublicGame(game),
      completedNode: completedNode ? toPublicCompletedNode(completedNode) : null,
      mapCompleted,
      summary,
    };
  });

  if (shouldRefreshLeaderboard && saveFlags.applied) {
    triggerLeaderboardRefreshAfterProgress(restriction, completed);
  }

  return response;
}

export async function resetAuthenticatedProgress(
  userId: string,
  restrictionInput?: unknown,
): Promise<ProgresoRestriccionResponse> {
  const restriction = restrictionInput === undefined || restrictionInput === null
    ? 'CELIAQUIA'
    : normalizeRestriction(restrictionInput);

  await withTransaction(async (client) => {
    await client.queryObject(`SELECT pg_advisory_xact_lock(hashtext($1)::bigint)`, [userId]);
    const user = await userRepository.findPublicUserByIdOnClient(client, userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const progressRow = await progressRepository.findProgressByUserAndRestriction(
      client,
      userId,
      restriction,
    );

    if (progressRow) {
      await historyGameRepository.deleteNodeHistoryByProgressId(client, progressRow.id);
      await progressRepository.resetProgressCounters(client, progressRow.id);
      // El leaderboard y el perfil leen profiles.exp_count (contador acumulado), no
      // progress_restrictions.total_exp. Tras poner total_exp en 0 hay que recalcular
      // exp_count desde las restricciones, o el XP viejo persistiría en ambos.
      await profileRepository.recomputeProfileExpFromRestrictions(client, userId);
    }
  });

  // Refrescamos el snapshot del leaderboard (global_xp + la restricción reseteada)
  // para que el ranking no siga mostrando el XP previo al reset.
  triggerLeaderboardRefreshAfterProgress(restriction, false);

  return getProgresoRestriccion(userId);
}

export async function saveProgressBatch(
  userId: string,
  items: unknown[],
): Promise<{
  synced: boolean;
  processed: number;
  createdSessions: number;
  ignoredDuplicates: number;
  results: Array<{
    clientRunId: string;
    ok: boolean;
    duplicate?: boolean;
    data?: unknown;
    error?: string;
  }>;
  summary: { total: number; synced: number; failed: number };
  progressSummary: ProgresoRestriccionResponse | null;
  progress: ProgresoRestriccionResponse['progress'] | null;
  streak: ProgresoRestriccionResponse['streak'] | null;
}> {
  if (!Array.isArray(items) || items.length === 0) {
    throw new PlayerError(400, 'INVALID_BODY', 'items debe ser un array no vacío');
  }
  if (items.length > 50) {
    throw new PlayerError(400, 'INVALID_BODY', 'máximo 50 ítems por batch');
  }

  const results: Array<{
    clientRunId: string;
    ok: boolean;
    duplicate?: boolean;
    data?: unknown;
    error?: string;
  }> = [];
  let synced = 0;
  let failed = 0;
  let createdSessions = 0;
  let ignoredDuplicates = 0;

  const ordered = [...items].sort((a, b) => {
    const dateA = typeof (a as Record<string, unknown>)?.finishedAt === 'string'
      ? (a as Record<string, string>).finishedAt
      : '';
    const dateB = typeof (b as Record<string, unknown>)?.finishedAt === 'string'
      ? (b as Record<string, string>).finishedAt
      : '';
    return dateA.localeCompare(dateB);
  });

  for (const item of ordered) {
    const clientRunId = typeof (item as Record<string, unknown>)?.clientRunId === 'string'
      ? (item as Record<string, string>).clientRunId.trim()
      : '';
    // Todo run local debe venir con clientRunId: es la clave de idempotencia
    // que garantiza que un reintento del mismo batch no duplique EXP/sesiones.
    if (!clientRunId) {
      results.push({ clientRunId, ok: false, error: 'clientRunId es requerido' });
      failed++;
      continue;
    }
    try {
      const data = await saveAuthenticatedProgress(
        { ...(item as object), userId },
        { includeSummary: false },
      );
      const duplicate = data.duplicate === true;
      if (duplicate) {
        ignoredDuplicates++;
      } else {
        createdSessions++;
      }
      results.push({
        clientRunId,
        ok: true,
        ...(duplicate ? { duplicate: true } : {}),
        data: {
          game: data.game,
          completedNode: data.completedNode ?? null,
          mapCompleted: data.mapCompleted ?? false,
        },
      });
      synced++;
    } catch (itemError) {
      const message = itemError instanceof Error ? itemError.message : 'error desconocido';
      results.push({ clientRunId, ok: false, error: message });
      failed++;
    }
  }

  const progressSummary = synced > 0 ? await getProgresoRestriccion(userId) : null;
  return {
    synced: failed === 0,
    processed: items.length,
    createdSessions,
    ignoredDuplicates,
    results,
    summary: { total: items.length, synced, failed },
    progressSummary,
    progress: progressSummary?.progress ?? null,
    streak: progressSummary?.streak ?? null,
  };
}
