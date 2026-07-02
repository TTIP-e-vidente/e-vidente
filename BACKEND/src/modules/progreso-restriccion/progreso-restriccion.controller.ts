import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import {
  getDevProgressByUsername,
  getProgresoRestriccion,
  resetAuthenticatedProgress,
  saveAuthenticatedProgress,
  saveDevProgress
} from './progreso-restriccion.service';
import { AppError } from '../../shared/errors/app_error';

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

export async function postProgressResetController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const response = await resetAuthenticatedProgress({
      userId,
      restriction: req.body?.restriction
    });
    sendResponse(res, 200, response);
  } catch (error) {
    sendError(res, error);
  }
}

export async function postBatchProgresoRestriccionController(
  req: Request,
  res: Response
): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) throw new AppError(401, 'UNAUTHORIZED', 'No active session');

    const { items } = req.body as { items?: unknown };
    if (!Array.isArray(items) || items.length === 0) {
      throw new AppError(400, 'INVALID_BODY', 'items debe ser un array no vacío');
    }
    if (items.length > 50) {
      throw new AppError(400, 'INVALID_BODY', 'máximo 50 ítems por batch');
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

    // Secuencial y ordenado por finishedAt: la racha depende del orden de aplicación
    // (un día viejo procesado después de uno nuevo se descarta). El advisory lock por
    // userId ya serializaba estos writes en Postgres, así que la concurrencia previa
    // no aportaba paralelismo real: solo orden no determinístico y conexiones ocupadas.
    const ordered = [...items].sort((a, b) => {
      const dateA = typeof (a as any)?.finishedAt === 'string' ? (a as any).finishedAt : '';
      const dateB = typeof (b as any)?.finishedAt === 'string' ? (b as any).finishedAt : '';
      return dateA.localeCompare(dateB);
    });

    for (const item of ordered) {
      const clientRunId =
        typeof (item as any)?.clientRunId === 'string'
          ? (item as any).clientRunId.trim()
          : '';
      // Todo run local debe venir con clientRunId: es la clave de idempotencia
      // que garantiza que un reintento del mismo batch no duplique EXP/sesiones.
      if (!clientRunId) {
        results.push({ clientRunId, ok: false, error: 'clientRunId es requerido' });
        failed++;
        continue;
      }
      try {
        // includeSummary: false — el estado consolidado se consulta una sola vez al final.
        const data = await saveAuthenticatedProgress(
          { ...(item as object), userId },
          { includeSummary: false }
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
        const message =
          itemError instanceof Error ? itemError.message : 'error desconocido';
        results.push({ clientRunId, ok: false, error: message });
        failed++;
      }
    }

    // Estado consolidado post-batch (racha, nodos, exp) para que el cliente
    // lo aplique a su save local sin otro round-trip.
    const progressSummary = synced > 0 ? await getProgresoRestriccion(userId) : null;

    sendResponse(res, 200, {
      synced: failed === 0,
      processed: items.length,
      createdSessions,
      ignoredDuplicates,
      results,
      summary: { total: items.length, synced, failed },
      progressSummary,
      progress: progressSummary?.progress ?? null,
      streak: progressSummary?.streak ?? null,
    });
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
