import { withTransaction } from '../db.ts';
import { PlayerError } from '../player-errors.ts';
import * as imageRepository from '../repositories/image.ts';
import {
  base64ToBytes,
  bytesToBase64,
  deleteAvatarObject,
  downloadAvatarBytes,
  isAvatarStorageConfigured,
  uploadAvatarBytes,
} from '../storage/avatars.ts';

const ALLOWED_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
const MAX_BASE64_LENGTH = 4 * 1024 * 1024;

async function resolveAvatarPayload(row: imageRepository.ImageRow): Promise<{
  data: string | null;
  mimeType: string | null;
  updatedAt: Date;
}> {
  if (row.storage_path && isAvatarStorageConfigured()) {
    const bytes = await downloadAvatarBytes(row.storage_path);
    if (bytes) {
      return {
        data: bytesToBase64(bytes),
        mimeType: row.mime_type,
        updatedAt: row.updated_at,
      };
    }
  }

  if (row.data) {
    return {
      data: row.data,
      mimeType: row.mime_type,
      updatedAt: row.updated_at,
    };
  }

  return {
    data: null,
    mimeType: null,
    updatedAt: row.updated_at,
  };
}

export async function uploadAvatar(userId: string, data: unknown, mimeType: unknown) {
  if (typeof data !== 'string' || data.trim().length === 0) {
    throw new PlayerError(400, 'INVALID_BODY', 'data must be a non-empty base64 string');
  }
  if (typeof mimeType !== 'string' || !ALLOWED_MIME_TYPES.includes(mimeType)) {
    throw new PlayerError(
      400,
      'INVALID_BODY',
      `mimeType must be one of: ${ALLOWED_MIME_TYPES.join(', ')}`,
    );
  }
  if (data.length > MAX_BASE64_LENGTH) {
    throw new PlayerError(413, 'PAYLOAD_TOO_LARGE', 'Avatar image exceeds maximum allowed size (3 MB)');
  }

  const trimmed = data.trim();
  let storagePath: string | null = null;

  if (isAvatarStorageConfigured()) {
    const bytes = base64ToBytes(trimmed);
    storagePath = await uploadAvatarBytes(userId, bytes, mimeType);
  }

  try {
    return await withTransaction(async (client) => {
      const row = await imageRepository.upsertUserAvatar(client, userId, {
        data: storagePath ? null : trimmed,
        storagePath,
        mimeType,
      });
      return { updatedAt: row.updated_at };
    });
  } catch (error) {
    if (storagePath) {
      await deleteAvatarObject(storagePath);
    }
    throw error;
  }
}

export async function deleteAvatar(userId: string) {
  let storagePath: string | null = null;

  await withTransaction(async (client) => {
    const result = await imageRepository.deleteUserAvatar(client, userId);
    storagePath = result.storagePath;
  });

  if (storagePath && isAvatarStorageConfigured()) {
    await deleteAvatarObject(storagePath);
  }

  return { deleted: true };
}

export async function getAvatarForUser(userId: string) {
  return await withTransaction(async (client) => {
    const row = await imageRepository.getImageByUserId(client, userId);
    if (!row) {
      return { data: null, mimeType: null };
    }

    const payload = await resolveAvatarPayload(row);
    if (!payload.data) {
      return { data: null, mimeType: null };
    }

    return {
      data: payload.data,
      mimeType: payload.mimeType,
      updatedAt: payload.updatedAt,
    };
  });
}
