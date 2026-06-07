import { PoolClient } from 'pg';

export interface ImageRow {
  id_image: string;
  user_id: string;
  data: string | null;
  mime_type: string | null;
  updated_at: Date;
}

export async function getImageByUserId(
  client: PoolClient,
  userId: string
): Promise<ImageRow | null> {
  const result = await client.query<ImageRow>(
    `
      SELECT id AS id_image, user_id, data, mime_type, updated_at
      FROM images
      WHERE user_id = $1
      LIMIT 1;
    `,
    [userId]
  );
  return result.rows[0] ?? null;
}

export async function upsertUserAvatar(
  client: PoolClient,
  userId: string,
  data: string,
  mimeType: string
): Promise<ImageRow> {
  // Upsert en images y actualiza avatar_image_id en users en una sola transacción.
  const result = await client.query<ImageRow>(
    `
      WITH upserted AS (
        INSERT INTO images (user_id, data, mime_type, updated_at)
        VALUES ($1, $2, $3, now())
        ON CONFLICT (user_id)
        DO UPDATE SET
          data       = EXCLUDED.data,
          mime_type  = EXCLUDED.mime_type,
          updated_at = now()
        RETURNING id, user_id, data, mime_type, updated_at
      )
      UPDATE users
      SET avatar_image_id = upserted.id
      FROM upserted
      WHERE users.id = upserted.user_id
      RETURNING
        upserted.id          AS id_image,
        upserted.user_id,
        upserted.data,
        upserted.mime_type,
        upserted.updated_at;
    `,
    [userId, data, mimeType]
  );
  return result.rows[0];
}
