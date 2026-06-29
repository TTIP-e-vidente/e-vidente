import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';
import bcrypt from 'npm:bcryptjs@2.4.3';
import * as jose from 'npm:jose@5';
import { withDb } from './db.ts';
import {
  buildVerificationSendMeta,
  sendVerificationCode,
  type SendVerificationResult,
} from './verification.ts';
import { ConfigError } from './jwt.ts';

export type AuthErrorCode =
  | 'INVALID_BODY'
  | 'INVALID_CREDENTIALS'
  | 'DUPLICATE_USERNAME'
  | 'DUPLICATE_MAIL';

export interface PublicUser {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  birth_date: string | null;
  email_notifications_enabled: boolean;
  mail_verified_at: string | null;
}

export interface AuthResponse {
  user: PublicUser;
  accessToken: string;
  verification?: {
    code_send_status: SendVerificationResult;
    cooldown_seconds: number;
    message: string;
    expires_minutes: number;
  };
}

export interface UserRow {
  id: string;
  username: string;
  password_hash: string | null;
  display_name: string | null;
  birth_date: Date | string | null;
  created_at: Date;
  updated_at: Date;
  name: string;
  mail: string | null;
  email_notifications_enabled: boolean;
  mail_verified_at: Date | null;
}

const USER_COLUMNS = `
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

export class AuthServiceError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: AuthErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'AuthServiceError';
  }
}

function asTrimmedString(value: unknown): string | null {
  return typeof value === 'string' ? value.trim() : null;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isValidEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function formatBirthDate(value: Date | string | null | undefined): string | null {
  if (value == null) {
    return null;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return /^\d{4}-\d{2}-\d{2}$/.test(trimmed) ? trimmed : null;
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  return null;
}

function parseBirthDateInput(value: unknown): string | null | undefined {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== 'string') {
    return undefined;
  }
  const trimmed = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    return undefined;
  }
  const [yearText, monthText, dayText] = trimmed.split('-');
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return undefined;
  }
  const today = new Date();
  const todayUtc = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  if (parsed.getTime() > todayUtc) {
    return undefined;
  }
  return trimmed;
}

function parseBooleanPreference(value: unknown, defaultValue: boolean): boolean {
  if (value === undefined || value === null) {
    return defaultValue;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'false' || normalized === '0' || normalized === 'no') {
      return false;
    }
    if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
      return true;
    }
  }
  return defaultValue;
}

function getBcryptSaltRounds(): number {
  const raw = Number.parseInt(Deno.env.get('BCRYPT_SALT_ROUNDS') ?? '10', 10);
  return Number.isNaN(raw) ? 10 : raw;
}

export function toPublicUser(user: UserRow): PublicUser {
  return {
    id: user.id,
    username: user.username,
    name: user.name,
    mail: user.mail,
    birth_date: formatBirthDate(user.birth_date),
    email_notifications_enabled: user.email_notifications_enabled,
    mail_verified_at: user.mail_verified_at ? user.mail_verified_at.toISOString() : null,
  };
}

export async function signAccessToken(user: UserRow): Promise<string> {
  const secret = Deno.env.get('JWT_SECRET')?.trim();
  if (!secret) {
    throw new ConfigError('JWT_SECRET not configured');
  }
  const key = new TextEncoder().encode(secret);
  const expiresIn = Deno.env.get('JWT_EXPIRES_IN')?.trim() || '1h';
  return await new jose.SignJWT({ username: user.username })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user.id)
    .setExpirationTime(expiresIn)
    .sign(key);
}

async function findById(db: Client, id: string): Promise<UserRow | null> {
  const result = await db.queryObject<UserRow>(
    `SELECT ${USER_COLUMNS} FROM users WHERE id = $1;`,
    [id],
  );
  return result.rows[0] ?? null;
}

async function findByUsername(db: Client, username: string): Promise<UserRow | null> {
  const result = await db.queryObject<UserRow>(
    `SELECT ${USER_COLUMNS} FROM users WHERE username = $1;`,
    [username],
  );
  return result.rows[0] ?? null;
}

async function findByMail(db: Client, mail: string): Promise<UserRow | null> {
  const result = await db.queryObject<UserRow>(
    `SELECT ${USER_COLUMNS} FROM users WHERE mail = $1;`,
    [mail],
  );
  return result.rows[0] ?? null;
}

async function findByUsernameOrMail(db: Client, value: string): Promise<UserRow | null> {
  const result = await db.queryObject<UserRow>(
    `SELECT ${USER_COLUMNS} FROM users WHERE username = $1 OR mail = $1;`,
    [value],
  );
  return result.rows[0] ?? null;
}

async function createUser(
  db: Client,
  input: {
    username: string;
    name: string;
    mail: string | null;
    passwordHash: string;
    birthDate: string | null;
    emailNotificationsEnabled: boolean;
  },
): Promise<UserRow> {
  const result = await db.queryObject<UserRow>(
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
      RETURNING ${USER_COLUMNS};
    `,
    [
      input.username,
      input.name,
      input.mail,
      input.passwordHash,
      input.birthDate,
      input.emailNotificationsEnabled,
    ],
  );
  return result.rows[0];
}

export async function login(input: Record<string, unknown>): Promise<AuthResponse> {
  const usernameOrMail = asTrimmedString(input.usernameOrMail);
  const password = asTrimmedString(input.password);

  if (!usernameOrMail || !password) {
    throw new AuthServiceError(400, 'INVALID_BODY', 'usernameOrMail and password are required');
  }

  return await withDb(async (db) => {
    const user = await findByUsernameOrMail(db, usernameOrMail);
    if (!user?.password_hash) {
      throw new AuthServiceError(401, 'INVALID_CREDENTIALS', 'Invalid credentials');
    }

    const passwordMatches = bcrypt.compareSync(password, user.password_hash);
    if (!passwordMatches) {
      throw new AuthServiceError(401, 'INVALID_CREDENTIALS', 'Invalid credentials');
    }

    return {
      user: toPublicUser(user),
      accessToken: await signAccessToken(user),
    };
  });
}

export async function register(input: Record<string, unknown>): Promise<AuthResponse> {
  const username = asTrimmedString(input.username);
  const name = asTrimmedString(input.name);
  const mailRaw = input.mail === undefined || input.mail === null
    ? null
    : asTrimmedString(input.mail);
  const mail = mailRaw && mailRaw.length > 0 ? mailRaw : null;
  const password = asTrimmedString(input.password);

  if (!isNonEmptyString(input.username) || !isNonEmptyString(input.name) || !password) {
    throw new AuthServiceError(400, 'INVALID_BODY', 'username, name and password are required');
  }

  const validUsername = input.username.trim();
  const validName = input.name.trim();

  if (password.length < 8) {
    throw new AuthServiceError(400, 'INVALID_BODY', 'password must have at least 8 characters');
  }

  if (mail && !isValidEmail(mail)) {
    throw new AuthServiceError(400, 'INVALID_BODY', 'mail must be a valid email');
  }

  const birthDate = parseBirthDateInput(input.birth_date);
  if (birthDate === undefined) {
    throw new AuthServiceError(400, 'INVALID_BODY', 'birth_date must be a valid ISO date (YYYY-MM-DD)');
  }

  return await withDb(async (db) => {
    const existingUsername = await findByUsername(db, validUsername);
    if (existingUsername) {
      throw new AuthServiceError(409, 'DUPLICATE_USERNAME', 'username already exists');
    }

    if (mail) {
      const existingMail = await findByMail(db, mail);
      if (existingMail) {
        throw new AuthServiceError(409, 'DUPLICATE_MAIL', 'mail already exists');
      }
    }

    const passwordHash = bcrypt.hashSync(password, getBcryptSaltRounds());
    const emailNotificationsEnabled = parseBooleanPreference(input.accept_email_notifications, false);
    const user = await createUser(db, {
      username: validUsername,
      name: validName,
      mail,
      passwordHash,
      birthDate,
      emailNotificationsEnabled,
    });

    let verification: AuthResponse['verification'];
    if (mail) {
      let sendResult: SendVerificationResult = 'send_failed';
      try {
        sendResult = await sendVerificationCode(user.id, mail, validName);
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        console.warn(`[edge:auth] post-register send failed for user ${user.id}: ${msg}`);
      }
      verification = await buildVerificationSendMeta(user.id, sendResult);
    }

    return {
      user: toPublicUser(user),
      accessToken: await signAccessToken(user),
      ...(verification ? { verification } : {}),
    };
  });
}

export async function getUserFromToken(userId: string): Promise<PublicUser> {
  return await withDb(async (db) => {
    const user = await findById(db, userId);
    if (!user) {
      throw new AuthServiceError(401, 'INVALID_CREDENTIALS', 'Invalid token');
    }
    return toPublicUser(user);
  });
}
