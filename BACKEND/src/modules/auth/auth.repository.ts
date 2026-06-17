import { query } from '../../config/database';
import { CreateUserInput, UserRow } from './auth.types';

const userColumns = `
  id,
  username,
  password_hash,
  display_name,
  birth_date,
  created_at,
  updated_at,
  name,
  mail,
  email_notifications_enabled,
  mail_verified_at
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
      WHERE mail = $1;
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
      WHERE username = $1 OR mail = $1;
    `,
    [value]
  );

  return result.rows[0] ?? null;
}

export async function createUser(input: CreateUserInput): Promise<UserRow> {
  const result = await query<UserRow>(
    `
      INSERT INTO users (
        username,
        name,
        mail,
        password_hash,
        birth_date,
        email_notifications_enabled
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING ${userColumns};
    `,
    [
      input.username,
      input.name,
      input.mail,
      input.passwordHash,
      input.birthDate,
      input.emailNotificationsEnabled
    ]
  );

  return result.rows[0];
}
