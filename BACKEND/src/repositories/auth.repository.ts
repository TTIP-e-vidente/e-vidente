import { query } from '../config/database';

export interface UserRow {
  id: string;
  username: string;
  email: string | null;
  password_hash: string | null;
  display_name: string | null;
  age: number | null;
  created_at: Date;
  updated_at: Date;
  name: string;
  mail: string | null;
}

export interface CreateUserInput {
  username: string;
  name: string;
  mail: string | null;
  passwordHash: string;
  age: number | null;
}

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
