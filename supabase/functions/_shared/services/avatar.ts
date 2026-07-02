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
const MAX_AVATAR_BYTES = 3 * 1024 * 1024;

// Si Storage está configurado pero el upload falla, este flag decide si se
// persiste el base64 legacy en la tabla images (true, default) o si se
// devuelve STORAGE_UNAVAILABLE (false).
function isBase64FallbackEnabled(): boolean {
  const raw = (Deno.env.get('AVATAR_BASE64_FALLBACK') ?? 'true').trim().toLowerCase();
  return !['false', '0', 'no'].includes(raw);
}

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
      'AVATAR_UNSUPPORTED_MIME',
      `mimeType must be one of: ${ALLOWED_MIME_TYPES.join(', ')}`,
    );
  }
  if (data.length > MAX_BASE64_LENGTH) {
    throw new PlayerError(413, 'AVATAR_TOO_LARGE', 'Avatar image exceeds maximum allowed size (3 MB)');
  }

  const trimmed = data.trim();

  // Validación sobre los bytes reales (el largo del base64 es aproximado) y
  // de que el base64 sea decodificable.
  let bytes: Uint8Array;
  try {
    bytes = base64ToBytes(trimmed);
  } catch {
    throw new PlayerError(400, 'INVALID_BODY', 'data must be valid base64');
  }
  if (bytes.length > MAX_AVATAR_BYTES) {
    throw new PlayerError(413, 'AVATAR_TOO_LARGE', 'Avatar image exceeds maximum allowed size (3 MB)');
  }

  // El path canónico ({userId}/avatar.{ext}) lo calcula siempre el backend;
  // el cliente solo manda base64 + mimeType.
  let storagePath: string | null = null;

  if (isAvatarStorageConfigured()) {
    try {
      storagePath = await uploadAvatarBytes(userId, bytes, mimeType);
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      console.warn(`[avatar] storage upload failed for user ${userId}: ${msg}`);
      if (!isBase64FallbackEnabled()) {
        throw new PlayerError(
          503,
          'STORAGE_UNAVAILABLE',
          'No se pudo guardar el avatar en Storage. Intentá de nuevo en unos minutos.',
        );
      }
      storagePath = null; // fallback: persiste base64 legacy en images.data
    }
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
    // Upload a Storage OK pero falló la DB: limpiar el objeto subido para no
    // dejar huérfanos que no coinciden con images.storage_path.
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
