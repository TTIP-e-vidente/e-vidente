import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';

export interface ImageRow {
  id_image: string;
  user_id: string;
  data: string | null;
  storage_path: string | null;
  mime_type: string | null;
  updated_at: Date;
}

export async function getImageByUserId(
  client: Client,
  userId: string,
): Promise<ImageRow | null> {
  const result = await client.queryObject<ImageRow>(
    `
      SELECT id AS id_image, user_id, data, storage_path, mime_type, updated_at
      FROM images
      WHERE user_id = $1
      LIMIT 1;
    `,
    [userId],
  );
  return result.rows[0] ?? null;
}

export async function deleteUserAvatar(
  client: Client,
  userId: string,
): Promise<{ deleted: boolean; storagePath: string | null }> {
  const existing = await getImageByUserId(client, userId);
  const storagePath = existing?.storage_path ?? null;

  await client.queryObject(
    `UPDATE users SET avatar_image_id = NULL WHERE id = $1;`,
    [userId],
  );
  const result = await client.queryObject(
    `DELETE FROM images WHERE user_id = $1;`,
    [userId],
  );
  return {
    deleted: (result.rowCount ?? 0) > 0,
    storagePath,
  };
}

export interface UpsertUserAvatarInput {
  data?: string | null;
  storagePath?: string | null;
  mimeType: string;
}

export async function upsertUserAvatar(
  client: Client,
  userId: string,
  input: UpsertUserAvatarInput,
): Promise<ImageRow> {
  const result = await client.queryObject<ImageRow>(
    `
      WITH upserted AS (
        INSERT INTO images (user_id, data, storage_path, mime_type, updated_at)
        VALUES ($1, $2, $3, $4, now())
        ON CONFLICT (user_id)
        DO UPDATE SET
          data         = EXCLUDED.data,
          storage_path = EXCLUDED.storage_path,
          mime_type    = EXCLUDED.mime_type,
          updated_at   = now()
        RETURNING id, user_id, data, storage_path, mime_type, updated_at
      )
      UPDATE users
      SET avatar_image_id = upserted.id
      FROM upserted
      WHERE users.id = upserted.user_id
      RETURNING
        upserted.id            AS id_image,
        upserted.user_id,
        upserted.data,
        upserted.storage_path,
        upserted.mime_type,
        upserted.updated_at;
    `,
    [userId, input.data ?? null, input.storagePath ?? null, input.mimeType],
  );
  return result.rows[0];
}
