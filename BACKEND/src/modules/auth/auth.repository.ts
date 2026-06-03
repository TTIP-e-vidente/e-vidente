import { PoolClient } from 'pg';
import { query } from '../../config/database';
import { CreateUserInput, PasswordResetTokenRow, UserRow } from './auth.types';

const userColumns = `
  id,
  username,
  email,
  password_hash,
  display_name,
  age,
  created_at,
  updated_at,
  name,
  mail
`;

export async function findById(id: string): Promise<UserRow | null> {
  const result = await query<UserRow>(
    `
      SELECT ${userColumns}
      FROM users
      WHERE id = $1;
    `,
    [id]
  );

  return result.rows[0] ?? null;
}

export async function findByUsername(username: string): Promise<UserRow | null> {
  const result = await query<UserRow>(
    `
      SELECT ${userColumns}
      FROM users
      WHERE username = $1;
    `,
    [username]
  );

  return result.rows[0] ?? null;
}

export async function findByMailOrEmail(mail: string): Promise<UserRow | null> {
  const result = await query<UserRow>(
    `
      SELECT ${userColumns}
      FROM users
      WHERE mail = $1 OR email = $1;
    `,
    [mail]
  );

  return result.rows[0] ?? null;
}

export async function findByUsernameOrMail(value: string): Promise<UserRow | null> {
  const result = await query<UserRow>(
    `
      SELECT ${userColumns}
      FROM users
      WHERE username = $1 OR mail = $1 OR email = $1;
    `,
    [value]
  );

  return result.rows[0] ?? null;
}

export async function createUser(input: CreateUserInput): Promise<UserRow> {
  const result = await query<UserRow>(
    `
      INSERT INTO users (username, name, mail, password_hash, age)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING ${userColumns};
    `,
    [input.username, input.name, input.mail, input.passwordHash, input.age]
  );

  return result.rows[0];
}

export async function createPasswordResetToken(
  userId: string,
  tokenHash: string,
  expiresAt: Date
): Promise<PasswordResetTokenRow> {
  const result = await query<PasswordResetTokenRow>(
    `
      INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
      VALUES ($1, $2, $3)
      RETURNING id, user_id, token_hash, expires_at, used_at, created_at;
    `,
    [userId, tokenHash, expiresAt]
  );

  return result.rows[0];
}

export async function findValidPasswordResetToken(
  client: PoolClient,
  tokenHash: string
): Promise<PasswordResetTokenRow | null> {
  const result = await client.query<PasswordResetTokenRow>(
    `
      SELECT id, user_id, token_hash, expires_at, used_at, created_at
      FROM password_reset_tokens
      WHERE token_hash = $1
        AND used_at IS NULL
        AND expires_at > now()
      ORDER BY created_at DESC
      LIMIT 1;
    `,
    [tokenHash]
  );

  return result.rows[0] ?? null;
}

export async function markPasswordResetTokenUsed(
  client: PoolClient,
  tokenId: string
): Promise<void> {
  await client.query(
    `
      UPDATE password_reset_tokens
      SET used_at = now()
      WHERE id = $1;
    `,
    [tokenId]
  );
}

export async function markOtherPasswordResetTokensUsed(
  client: PoolClient,
  userId: string,
  usedTokenId: string
): Promise<void> {
  await client.query(
    `
      UPDATE password_reset_tokens
      SET used_at = now()
      WHERE user_id = $1
        AND id <> $2
        AND used_at IS NULL
        AND expires_at > now();
    `,
    [userId, usedTokenId]
  );
}

export async function updatePasswordHash(
  client: PoolClient,
  userId: string,
  passwordHash: string
): Promise<void> {
  await client.query(
    `
      UPDATE users
      SET password_hash = $2,
          updated_at = now()
      WHERE id = $1;
    `,
    [userId, passwordHash]
  );
}
