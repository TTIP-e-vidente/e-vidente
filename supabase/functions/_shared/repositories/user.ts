import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';
import { withDb } from '../db.ts';
import { UpdateUserProfileInput, UserPublicRow } from '../types/player.ts';

export async function findPublicUserById(userId: string): Promise<UserPublicRow | null> {
  return withDb(async (db) => findPublicUserByIdOnClient(db, userId));
}

export async function findPublicUserByIdOnClient(
  client: Client,
  userId: string,
): Promise<UserPublicRow | null> {
  const result = await client.queryObject<UserPublicRow>(
    `
      SELECT id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at
      FROM users
      WHERE id = $1;
    `,
    [userId],
  );
  return result.rows[0] ?? null;
}

export async function findPublicUserByUsername(
  client: Client,
  username: string,
): Promise<UserPublicRow | null> {
  const result = await client.queryObject<UserPublicRow>(
    `
      SELECT id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at
      FROM users
      WHERE username = $1;
    `,
    [username],
  );
  return result.rows[0] ?? null;
}

export async function findByMailExcludingUserId(
  client: Client,
  mail: string,
  excludeUserId: string,
): Promise<UserPublicRow | null> {
  const result = await client.queryObject<UserPublicRow>(
    `
      SELECT id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at
      FROM users
      WHERE mail = $1 AND id <> $2;
    `,
    [mail, excludeUserId],
  );
  return result.rows[0] ?? null;
}

export async function updateUserProfile(
  client: Client,
  userId: string,
  input: UpdateUserProfileInput,
): Promise<UserPublicRow | null> {
  const sets: string[] = ['updated_at = now()'];
  const params: unknown[] = [userId];
  let paramIndex = 2;

  if (input.name !== undefined) {
    sets.push(`name = $${paramIndex++}`);
    params.push(input.name);
    sets.push(`display_name = $${paramIndex++}`);
    params.push(input.name);
  }

  if (input.mail !== undefined) {
    const mailParamIndex = paramIndex++;
    const mailCompareParamIndex = paramIndex++;
    sets.push(`mail = $${mailParamIndex}`);
    params.push(input.mail);
    params.push(input.mail);
    sets.push(
      `mail_verified_at = CASE
        WHEN lower(coalesce(mail::text, '')) = lower(coalesce($${mailCompareParamIndex}::text, ''))
          THEN mail_verified_at
        ELSE NULL
      END`,
    );
  }

  if (input.birth_date !== undefined) {
    sets.push(`birth_date = $${paramIndex++}`);
    params.push(input.birth_date);
  }

  if (input.email_notifications_enabled !== undefined) {
    sets.push(`email_notifications_enabled = $${paramIndex++}`);
    params.push(input.email_notifications_enabled);
  }

  const result = await client.queryObject<UserPublicRow>(
    `
      UPDATE users
      SET ${sets.join(', ')}
      WHERE id = $1
      RETURNING id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at;
    `,
    params,
  );

  return result.rows[0] ?? null;
}
