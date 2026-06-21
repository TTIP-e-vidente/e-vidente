import { Router } from 'express';
import { authenticateToken } from '../../shared/middlewares/authenticate-token';
import { optionalAuthenticateToken } from '../../shared/middlewares/optional-authenticate-token';
import {
  getLeaderboardController,
  getLeaderboardMetaController,
  getMyLeaderboardPositionController,
  getMyRankingSummaryController
} from './leaderboard.controller';

export const leaderboardRouter = Router();

/**
 * GET /leaderboard
 * Público. Usa auth opcional para soportar include_self=true con Bearer token.
 * Scopes: global_xp | streak
 * Query: ?scope=global_xp&limit=50&offset=0&include_self=true
 */
leaderboardRouter.get('/', optionalAuthenticateToken, getLeaderboardController);

/**
 * GET /leaderboard/meta
 * Público. Estado de salud de los snapshots (última ejecución, errores, row_count).
 */
leaderboardRouter.get('/meta', getLeaderboardMetaController);

/**
 * GET /leaderboard/me
 * Autenticado. Posición propia en todos los scopes.
 */
leaderboardRouter.get('/me', authenticateToken, getMyLeaderboardPositionController);

/**
 * GET /leaderboard/me/summary
 * Autenticado. Contexto competitivo: puesto actual, siguiente rival, EXP faltante.
 * Responde { available: false } si el jugador no tiene progreso registrado.
 */
leaderboardRouter.get('/me/summary', authenticateToken, getMyRankingSummaryController);
