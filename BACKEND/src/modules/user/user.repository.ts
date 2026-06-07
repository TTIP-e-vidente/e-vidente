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
      SELECT id, username, name, COALESCE(mail, email) AS mail, birth_date
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
      SELECT id, username, name, COALESCE(mail, email) AS mail, birth_date
      FROM users
      WHERE username = $1;
    `,
    [username]
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
      RETURNING id, username, name, COALESCE(mail, email) AS mail, birth_date;
    `,
    [username, name]
  );

  return result.rows[0];
}
