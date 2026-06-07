import { Request, Response } from 'express';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import {
  getDevProgressByUsername,
  getProgresoRestriccion,
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

    const results: Array<{ clientRunId: string; ok: boolean; data?: unknown; error?: string }> = [];
    let synced = 0;
    let failed = 0;

    for (const item of items) {
      const clientRunId = typeof (item as any)?.clientRunId === 'string'
        ? (item as any).clientRunId
        : '';
      try {
        const data = await saveAuthenticatedProgress({ ...(item as object), userId });
        results.push({ clientRunId, ok: true, data });
        synced++;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'error desconocido';
        results.push({ clientRunId, ok: false, error: message });
        failed++;
      }
    }

    sendResponse(res, 200, {
      results,
      summary: { total: items.length, synced, failed }
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
