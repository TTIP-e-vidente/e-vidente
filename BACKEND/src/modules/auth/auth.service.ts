import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt, { SignOptions } from 'jsonwebtoken';
import { authConfig, assertAuthConfig } from '../../config/auth';
import { pool } from '../../config/database';
import { AppError } from '../../shared/errors/app_error';
import { isNonEmptyString, isValidEmail } from '../../shared/validation/validators';
import { toPublicUser } from './auth.mapper';
import * as authRepository from './auth.repository';
import {
  AuthErrorCode,
  AuthResponse,
  ForgotPasswordInput,
  ForgotPasswordResponse,
  LoginInput,
  PublicUser,
  RegisterInput,
  ResetPasswordInput,
  ResetPasswordResponse,
  UserRow
} from './auth.types';

const forgotPasswordMessage =
  'If an account exists for that mail, password reset instructions were generated.';

export class AuthError extends AppError {
  constructor(statusCode: number, code: AuthErrorCode, message: string) {
    super(statusCode, code, message);
  }
}

function asTrimmedString(value: unknown): string | null {
  return typeof value === 'string' ? value.trim() : null;
}

function getBcryptSaltRounds(): number {
  return Number.isNaN(authConfig.bcryptSaltRounds) ? 10 : authConfig.bcryptSaltRounds;
}

function getPasswordResetTokenExpiresMinutes(): number {
  return Number.isNaN(authConfig.passwordResetTokenExpiresMinutes)
    ? 30
    : authConfig.passwordResetTokenExpiresMinutes;
}

function generateResetToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

function hashResetToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function signAccessToken(user: UserRow): string {
  assertAuthConfig();

  const options: SignOptions = {
    expiresIn: authConfig.jwtExpiresIn as SignOptions['expiresIn']
  };

  return jwt.sign({ username: user.username }, authConfig.jwtSecret, {
    ...options,
    subject: user.id
  });
}

export function verifyAccessToken(token: string): { sub: string; username: string } {
  assertAuthConfig();

  const payload = jwt.verify(token, authConfig.jwtSecret);
  if (
    typeof payload !== 'object' ||
    payload === null ||
    typeof payload.sub !== 'string' ||
    typeof payload.username !== 'string'
  ) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid token');
  }

  return { sub: payload.sub, username: payload.username };
}

export async function register(input: RegisterInput): Promise<AuthResponse> {
  const username = asTrimmedString(input.username);
  const name = asTrimmedString(input.name);
  const mail = input.mail === undefined || input.mail === null ? null : asTrimmedString(input.mail);
  const password = asTrimmedString(input.password);

  if (!isNonEmptyString(input.username) || !isNonEmptyString(input.name) || !password) {
    throw new AuthError(400, 'INVALID_BODY', 'username, name and password are required');
  }
  const validUsername = input.username.trim();
  const validName = input.name.trim();

  if (password.length < 8) {
    throw new AuthError(400, 'INVALID_BODY', 'password must have at least 8 characters');
  }

  if (mail && !isValidEmail(mail)) {
    throw new AuthError(400, 'INVALID_BODY', 'mail must be a valid email');
  }

  const age =
    input.age === undefined || input.age === null
      ? null
      : typeof input.age === 'number' && Number.isInteger(input.age) && input.age >= 0
        ? input.age
        : undefined;

  if (age === undefined) {
    throw new AuthError(400, 'INVALID_BODY', 'age must be a positive integer');
  }

  const existingUsername = await authRepository.findByUsername(validUsername);
  if (existingUsername) {
    throw new AuthError(409, 'DUPLICATE_USERNAME', 'username already exists');
  }

  if (mail) {
    const existingMail = await authRepository.findByMailOrEmail(mail);
    if (existingMail) {
      throw new AuthError(409, 'DUPLICATE_MAIL', 'mail already exists');
    }
  }

  const passwordHash = await bcrypt.hash(password, getBcryptSaltRounds());
  const user = await authRepository.createUser({
    username: validUsername,
    name: validName,
    mail,
    passwordHash,
    age
  });

  return {
    user: toPublicUser(user),
    accessToken: signAccessToken(user)
  };
}

export async function login(input: LoginInput): Promise<AuthResponse> {
  const usernameOrMail = asTrimmedString(input.usernameOrMail);
  const password = asTrimmedString(input.password);

  if (!usernameOrMail || !password) {
    throw new AuthError(400, 'INVALID_BODY', 'usernameOrMail and password are required');
  }

  const user = await authRepository.findByUsernameOrMail(usernameOrMail);
  if (!user?.password_hash) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid credentials');
  }

  const passwordMatches = await bcrypt.compare(password, user.password_hash);
  if (!passwordMatches) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid credentials');
  }

  return {
    user: toPublicUser(user),
    accessToken: signAccessToken(user)
  };
}

export async function getUserFromToken(token: string): Promise<PublicUser> {
  const payload = verifyAccessToken(token);
  const user = await authRepository.findById(payload.sub);

  if (!user) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid token');
  }

  return toPublicUser(user);
}

export async function forgotPassword(
  input: ForgotPasswordInput
): Promise<ForgotPasswordResponse> {
  const mail = asTrimmedString(input.mail);
  if (!mail) {
    throw new AuthError(400, 'INVALID_BODY', 'mail is required');
  }

  if (!isValidEmail(mail)) {
    throw new AuthError(400, 'INVALID_BODY', 'mail must be a valid email');
  }

  const response: ForgotPasswordResponse = {
    status: 'ok',
    message: forgotPasswordMessage
  };

  const user = await authRepository.findByMailOrEmail(mail);
  if (!user) {
    return response;
  }

  const resetToken = generateResetToken();
  const tokenHash = hashResetToken(resetToken);
  const expiresAt = new Date(
    Date.now() + getPasswordResetTokenExpiresMinutes() * 60 * 1000
  );

  await authRepository.createPasswordResetToken(user.id, tokenHash, expiresAt);

  if (process.env.NODE_ENV !== 'production') {
    response.devResetToken = resetToken;
  }

  return response;
}

export async function resetPassword(
  input: ResetPasswordInput
): Promise<ResetPasswordResponse> {
  const token = asTrimmedString(input.token);
  const newPassword = asTrimmedString(input.newPassword);

  if (!token) {
    throw new AuthError(400, 'INVALID_BODY', 'token is required');
  }

  if (!newPassword || newPassword.length < 8) {
    throw new AuthError(400, 'INVALID_BODY', 'newPassword must have at least 8 characters');
  }

  const tokenHash = hashResetToken(token);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const resetToken = await authRepository.findValidPasswordResetToken(client, tokenHash);
    if (!resetToken) {
      throw new AuthError(400, 'INVALID_RESET_TOKEN', 'Invalid or expired reset token');
    }

    const passwordHash = await bcrypt.hash(newPassword, getBcryptSaltRounds());
    await authRepository.updatePasswordHash(client, resetToken.user_id, passwordHash);
    await authRepository.markPasswordResetTokenUsed(client, resetToken.id);
    await authRepository.markOtherPasswordResetTokensUsed(
      client,
      resetToken.user_id,
      resetToken.id
    );

    await client.query('COMMIT');
    return {
      status: 'ok',
      message: 'Password updated'
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
