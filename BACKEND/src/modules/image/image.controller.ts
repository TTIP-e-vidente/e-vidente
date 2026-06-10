import { Request, Response } from 'express';
import { pool } from '../../config/database';
import { AppError } from '../../shared/errors/app_error';
import { sendError } from '../../shared/http/send-error';
import { sendResponse } from '../../shared/http/send-response';
import { deleteUserAvatar, getImageByUserId, upsertUserAvatar } from './image.repository';

const ALLOWED_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
const MAX_BASE64_LENGTH = 4 * 1024 * 1024; // ~3 MB imagen original

export async function uploadAvatarController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) throw new AppError(401, 'UNAUTHORIZED', 'No active session');

    const { data, mimeType } = req.body as { data?: unknown; mimeType?: unknown };

    if (typeof data !== 'string' || data.trim().length === 0) {
      throw new AppError(400, 'INVALID_BODY', 'data must be a non-empty base64 string');
    }
    if (typeof mimeType !== 'string' || !ALLOWED_MIME_TYPES.includes(mimeType)) {
      throw new AppError(
        400,
        'INVALID_BODY',
        `mimeType must be one of: ${ALLOWED_MIME_TYPES.join(', ')}`
      );
    }
    if (data.length > MAX_BASE64_LENGTH) {
      throw new AppError(413, 'PAYLOAD_TOO_LARGE', 'Avatar image exceeds maximum allowed size (3 MB)');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const row = await upsertUserAvatar(client, userId, data.trim(), mimeType);
      await client.query('COMMIT');
      sendResponse(res, 200, { updatedAt: row.updated_at });
    } catch (dbError) {
      await client.query('ROLLBACK');
      throw dbError;
    } finally {
      client.release();
    }
  } catch (error) {
    sendError(res, error);
  }
}

export async function deleteAvatarController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) throw new AppError(401, 'UNAUTHORIZED', 'No active session');

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await deleteUserAvatar(client, userId);
      await client.query('COMMIT');
      sendResponse(res, 200, { deleted: true });
    } catch (dbError) {
      await client.query('ROLLBACK');
      throw dbError;
    } finally {
      client.release();
    }
  } catch (error) {
    sendError(res, error);
  }
}

export async function getAvatarController(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user?.id;
    if (!userId) throw new AppError(401, 'UNAUTHORIZED', 'No active session');

    const client = await pool.connect();
    try {
      const row = await getImageByUserId(client, userId);
      if (!row || !row.data) {
        sendResponse(res, 200, { data: null, mimeType: null });
        return;
      }
      sendResponse(res, 200, { data: row.data, mimeType: row.mime_type, updatedAt: row.updated_at });
    } finally {
      client.release();
    }
  } catch (error) {
    sendError(res, error);
  }
}
