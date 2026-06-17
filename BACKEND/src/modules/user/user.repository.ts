/**
 * USER del MER.
 *
 * Responsabilidad:
 * - Consultar y crear usuarios en la base de datos.
 *
 * No debe:
 * - Devolver password_hash en consultas públicas.
 */
import { PoolClient } from 'pg';
import { query } from '../../config/database';
import { UserPublicRow } from './user.types';

export async function findPublicUserById(userId: string): Promise<UserPublicRow | null> {
  const result = await query<UserPublicRow>(
    `
      SELECT id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at
      FROM users
      WHERE id = $1;
    `,
    [userId]
  );

  return result.rows[0] ?? null;
}

export async function findPublicUserByUsername(
  client: PoolClient,
  username: string
): Promise<UserPublicRow | null> {
  const result = await client.query<UserPublicRow>(
    `
      SELECT id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at
      FROM users
      WHERE username = $1;
    `,
    [username]
  );

  return result.rows[0] ?? null;
}

export interface UpdateUserProfileInput {
  name?: string;
  mail?: string | null;
  birth_date?: string | null;
  email_notifications_enabled?: boolean;
}

export async function findByMailExcludingUserId(
  mailOrClient: string | PoolClient,
  mailOrExcludeId: string,
  maybeExcludeId?: string
): Promise<UserPublicRow | null> {
  let executor: { query: PoolClient['query'] };
  let mail: string;
  let excludeUserId: string;

  if (typeof mailOrClient === 'string') {
    executor = { query: (text: string, values?: unknown[]) => query(text, values) } as { query: PoolClient['query'] };
    mail = mailOrClient;
    excludeUserId = mailOrExcludeId;
  } else {
    executor = mailOrClient;
    mail = mailOrExcludeId;
    excludeUserId = maybeExcludeId!;
  }

  const result = await executor.query<UserPublicRow>(
    `
      SELECT id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at
      FROM users
      WHERE mail = $1 AND id <> $2;
    `,
    [mail, excludeUserId]
  );

  return result.rows[0] ?? null;
}

export async function updateUserProfile(
  client: PoolClient,
  userId: string,
  input: UpdateUserProfileInput
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
    sets.push(`mail = $${paramIndex++}`);
    params.push(input.mail);
    // Al cambiar el mail, se resetea la verificación automáticamente
    sets.push('mail_verified_at = NULL');
  }

  if (input.birth_date !== undefined) {
    sets.push(`birth_date = $${paramIndex++}`);
    params.push(input.birth_date);
  }

  if (input.email_notifications_enabled !== undefined) {
    sets.push(`email_notifications_enabled = $${paramIndex++}`);
    params.push(input.email_notifications_enabled);
  }

  const result = await client.query<UserPublicRow>(
    `
      UPDATE users
      SET ${sets.join(', ')}
      WHERE id = $1
      RETURNING id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at;
    `,
    params
  );

  return result.rows[0] ?? null;
}

export async function upsertDevUser(
  client: PoolClient,
  username: string,
  name: string
): Promise<UserPublicRow> {
  const result = await client.query<UserPublicRow>(
    `
      INSERT INTO users (username, name, display_name)
      VALUES ($1, $2, $2)
      ON CONFLICT (username)
      DO UPDATE SET
        name = COALESCE(EXCLUDED.name, users.name),
        display_name = COALESCE(EXCLUDED.name, users.display_name),
        updated_at = now()
      RETURNING id, username, name, mail, birth_date, email_notifications_enabled, mail_verified_at;
    `,
    [username, name]
  );

  return result.rows[0];
}
