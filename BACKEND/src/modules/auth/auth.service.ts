import bcrypt from 'bcryptjs';
import jwt, { SignOptions } from 'jsonwebtoken';
import { authConfig, assertAuthConfig } from '../../config/auth';
import { AppError } from '../../shared/errors/app_error';
import { isNonEmptyString, isValidEmail } from '../../shared/validation/validators';
import { parseBirthDateInput } from '../../shared/validation/birth_date';
import { toPublicUser } from './auth.mapper';
import * as authRepository from './auth.repository';
import {
  AuthErrorCode,
  AuthResponse,
  LoginInput,
  PublicUser,
  RegisterInput,
  UserRow
} from './auth.types';

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

  const birthDate = parseBirthDateInput(input.birth_date);

  if (birthDate === undefined) {
    throw new AuthError(400, 'INVALID_BODY', 'birth_date must be a valid ISO date (YYYY-MM-DD)');
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
    birthDate
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
