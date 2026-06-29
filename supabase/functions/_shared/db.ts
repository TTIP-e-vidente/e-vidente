import { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';

function databaseUrl(): string {
  const url =
    Deno.env.get('DATABASE_URL')?.trim() ||
    Deno.env.get('SUPABASE_DB_URL')?.trim();
  if (!url) {
    throw new Error(
      'DATABASE_URL not configured (custom secret o SUPABASE_DB_URL por defecto)',
    );
  }
  return url;
}

export async function withDb<T>(
  fn: (db: Client) => Promise<T>,
): Promise<T> {
  const db = new Client(databaseUrl());
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}

export async function withTransaction<T>(
  fn: (db: Client) => Promise<T>,
): Promise<T> {
  return withDb(async (db) => {
    await db.queryObject('BEGIN');
    try {
      const result = await fn(db);
      await db.queryObject('COMMIT');
      return result;
    } catch (error) {
      await db.queryObject('ROLLBACK');
      throw error;
    }
  });
}

export interface PublicUserRow {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  mail_verified_at: Date | null;
}

export async function findPublicUserById(
  db: Client,
  userId: string,
): Promise<PublicUserRow | null> {
  const result = await db.queryObject<PublicUserRow>(
    `
      SELECT id, username, name, mail, mail_verified_at
      FROM users
      WHERE id = $1;
    `,
    [userId],
  );
  return result.rows[0] ?? null;
}
