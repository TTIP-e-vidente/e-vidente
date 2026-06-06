import { PoolClient } from 'pg';

export interface ImageRow {
  id_image: string;
  user_id: string;
  updated_at: Date;
}

export async function getImageByUserId(
  client: PoolClient,
  userId: string
): Promise<ImageRow | null> {
  const result = await client.query<ImageRow>(
    `
      SELECT id AS id_image, user_id, updated_at
      FROM images
      WHERE user_id = $1
      LIMIT 1;
    `,
    [userId]
  );
  return result.rows[0] ?? null;
}
