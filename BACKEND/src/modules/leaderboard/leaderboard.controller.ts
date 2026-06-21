import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import {
  getLeaderboard,
  getLeaderboardMeta,
  getUserLeaderboardPositions,
  getUserRankingSummary,
  parseScope
} from './leaderboard.service';
import { LEADERBOARD_SCOPES } from './leaderboard.types';
import {
  serializeLeaderboardResult,
  serializeMeta,
  serializeRankingSummary,
  serializeUserPosition
} from './leaderboard.mapper';

// ─── HTTP caching helpers ──────────────────────────────────────────────────────

function applyHttpCacheHeaders(
  response: Response,
  computedAt: Date | null,
  isLiveFallback: boolean,
  hasPersonalData: boolean
): void {
  if (hasPersonalData) {
    // Contiene datos personales (own_position) — no cachear en CDN
    response.setHeader('Cache-Control', 'private, no-store');
    return;
  }
  if (isLiveFallback) {
    response.setHeader('Cache-Control', 'public, max-age=10');
    return;
  }
  // Snapshot: cacheable 60s, stale tolerable 5min
  response.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=300');
  if (computedAt) {
    response.setHeader('Last-Modified', computedAt.toUTCString());
    response.setHeader('ETag', `"lb-${computedAt.getTime()}"`);
  }
}

function isNotModified(request: Request, computedAt: Date | null): boolean {
  if (!computedAt) return false;

  const etag = `"lb-${computedAt.getTime()}"`;
  if (request.headers['if-none-match'] === etag) return true;

  const ifModifiedSince = request.headers['if-modified-since'];
  if (ifModifiedSince) {
    const clientDate = new Date(ifModifiedSince);
    if (!isNaN(clientDate.getTime()) && computedAt <= clientDate) return true;
  }

  return false;
}

// ─── Controllers ──────────────────────────────────────────────────────────────

/**
 * GET /leaderboard
 * Público (soporta Bearer opcional para include_self).
 *
 * Query params:
 *   scope        : 'global_xp' | 'streak'     (default: 'global_xp')
 *   limit        : 1..200                      (default: 50)
 *   offset       : 0..                         (default: 0)
 *   include_self : 'true'  → agrega posición propia si Bearer es válido
 */
export async function getLeaderboardController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const { scope, limit, offset, include_self } = request.query;

    if (scope !== undefined && !parseScope(scope)) {
      sendResponse(response, 400, {
        error: `scope inválido. Valores aceptados: ${LEADERBOARD_SCOPES.join(', ')}`
      });
      return;
    }

    const includeSelf = include_self === 'true';
    const userId      = request.user?.id ?? null;

    const result = await getLeaderboard({ scope, limit, offset, includeSelf, userId });

    // 304 Not Modified (solo aplica cuando no hay datos personales)
    if (!includeSelf && isNotModified(request, result.computedAt)) {
      response.status(304).end();
      return;
    }

    const hasPersonalData = includeSelf && !!result.ownPosition;
    applyHttpCacheHeaders(response, result.computedAt, result.isLiveFallback, hasPersonalData);

    sendResponse(response, 200, serializeLeaderboardResult(result));
  } catch (error) {
    sendError(response, error);
  }
}

/**
 * GET /leaderboard/me
 * Autenticado. Devuelve la posición propia en todos los scopes disponibles.
 */
export async function getMyLeaderboardPositionController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const userId = request.user?.id;
    if (!userId) {
      sendResponse(response, 401, { error: 'Unauthorized' });
      return;
    }

    const positions = await getUserLeaderboardPositions(userId);

    response.setHeader('Cache-Control', 'private, max-age=30');
    sendResponse(response, 200, {
      positions: positions.map(serializeUserPosition)
    });
  } catch (error) {
    sendError(response, error);
  }
}

/**
 * GET /leaderboard/meta
 * Público. Estado de salud de los snapshots (frescura, errores, generación).
 */
export async function getLeaderboardMetaController(
  _request: Request,
  response: Response
): Promise<void> {
  try {
    const metas = await getLeaderboardMeta();

    response.setHeader('Cache-Control', 'public, max-age=30');
    sendResponse(response, 200, {
      snapshots: metas.map(serializeMeta),
      all_ok: metas.every((m) => !m.errorMessage && m.lastRefreshedAt !== null)
    });
  } catch (error) {
    sendError(response, error);
  }
}

/**
 * GET /leaderboard/me/summary
 * Autenticado. Devuelve el contexto competitivo del jugador:
 *   - Su posición actual y EXP
 *   - El jugador que está un puesto por encima
 *   - Cuánta EXP necesita para superarlo
 *   - Porcentaje de progreso hacia el siguiente puesto
 *
 * Si no hay datos (jugador sin progreso), retorna available: false.
 * Nunca falla con 5xx: errores internos retornan available: false.
 */
export async function getMyRankingSummaryController(
  request: Request,
  response: Response
): Promise<void> {
  try {
    const userId = request.user?.id;
    if (!userId) {
      sendResponse(response, 401, { error: 'Unauthorized' });
      return;
    }

    const scopeParam = request.query.scope;
    const scope = scopeParam !== undefined ? parseScope(scopeParam) : 'global_xp';
    if (scopeParam !== undefined && !scope) {
      sendResponse(response, 400, {
        error: `scope inválido. Valores aceptados: ${LEADERBOARD_SCOPES.join(', ')}`
      });
      return;
    }

    const summary = await getUserRankingSummary(userId, scope ?? 'global_xp');

    response.setHeader('Cache-Control', 'private, max-age=30');

    if (!summary) {
      // El jugador existe pero no tiene progreso registrado.
      sendResponse(response, 200, { available: false });
      return;
    }

    sendResponse(response, 200, {
      available: true,
      ...serializeRankingSummary(summary)
    });
  } catch (error) {
    sendError(response, error);
  }
}
