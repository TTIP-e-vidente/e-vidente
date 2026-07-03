import bcrypt from 'bcryptjs';
import jwt, { SignOptions } from 'jsonwebtoken';
import { authConfig, assertAuthConfig } from '../../config/auth';
import { AppError } from '../../shared/errors/app_error';
import { isNonEmptyString, isValidEmail } from '../../shared/validation/validators';
import { parseBirthDateInput } from '../../shared/validation/birth_date';
import { toPublicUser } from './auth.mapper';
import * as authRepository from './auth.repository';
import {
  buildVerificationSendMeta,
  sendVerificationCode
} from '../email/email.verification.service';
import {
  AuthErrorCode,
  AuthResponse,
  LoginInput,
  PublicUser,
  RegisterInput,
  UserRow
} from './auth.types';

export class AuthError extends AppError {
  constructor(
    statusCode: number,
    code: AuthErrorCode,
    message: string,
    details?: Record<string, unknown>
  ) {
    super(statusCode, code, message, details);
  }
}

function asTrimmedString(value: unknown): string | null {
  return typeof value === 'string' ? value.trim() : null;
}

function getBcryptSaltRounds(): number {
  return Number.isNaN(authConfig.bcryptSaltRounds) ? 10 : authConfig.bcryptSaltRounds;
}

// Token acotado: solo sirve para pedir/confirmar el código de verificación de mail.
export const VERIFICATION_TOKEN_SCOPE = 'email_verification';

function signAccessToken(user: UserRow, scope?: string): string {
  assertAuthConfig();

  const options: SignOptions = {
    expiresIn: authConfig.jwtExpiresIn as SignOptions['expiresIn']
  };

  return jwt.sign(
    { username: user.username, ...(scope ? { scope } : {}) },
    authConfig.jwtSecret,
    {
      ...options,
      subject: user.id
    }
  );
}

export function verifyAccessToken(
  token: string
): { sub: string; username: string; scope?: string } {
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

  const scope = typeof payload.scope === 'string' ? payload.scope : undefined;
  return { sub: payload.sub, username: payload.username, ...(scope ? { scope } : {}) };
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

function parseEmailNotificationsPreference(value: unknown): boolean {
  return parseBooleanPreference(value, false);
}

export async function register(input: RegisterInput): Promise<AuthResponse> {
  const username = asTrimmedString(input.username);
  const name = asTrimmedString(input.name);
  const mailRaw = input.mail === undefined || input.mail === null ? null : asTrimmedString(input.mail);
  const mail = mailRaw && mailRaw.length > 0 ? mailRaw : null;
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

  const passwordHash = await bcrypt.hash(password, getBcryptSaltRounds());
  const emailNotificationsEnabled = parseEmailNotificationsPreference(
    input.accept_email_notifications
  );
  const user = await authRepository.createUser({
    username: validUsername,
    name: validName,
    mail,
    passwordHash,
    birthDate,
    emailNotificationsEnabled
  });

  let verification: AuthResponse['verification'];
  if (mail) {
    let sendResult: Awaited<ReturnType<typeof sendVerificationCode>> = 'send_failed';
    try {
      sendResult = await sendVerificationCode(user.id, mail, validName);
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      console.warn(`[email:verify] post-register send failed for user ${user.id}: ${msg}`);
    }
    verification = await buildVerificationSendMeta(user.id, sendResult);
  }
  // Welcome solo tras verificar mail (confirmVerificationController).

  return {
    user: toPublicUser(user),
    accessToken: signAccessToken(user),
    ...(verification ? { verification } : {})
  };
}

export async function login(input: LoginInput): Promise<AuthResponse> {
  const usernameOrMail = asTrimmedString(input.usernameOrMail);
  const password = asTrimmedString(input.password);

  if (!usernameOrMail || !password) {
    throw new AuthError(400, 'INVALID_BODY', 'usernameOrMail and password are required');
  }

  const user = await findLoginUser(usernameOrMail, password);
  if (!user?.password_hash) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid credentials');
  }

  if (user.mail && !user.mail_verified_at) {
    // Password correcta pero mail sin verificar: no se entrega sesión completa.
    // El token acotado solo habilita verify-email/request|confirm y email-status;
    // el código se (re)envía acá respetando el cooldown para que el usuario
    // aterrice en la pantalla de verificación con un OTP vigente.
    let sendResult: Awaited<ReturnType<typeof sendVerificationCode>> = 'send_failed';
    try {
      sendResult = await sendVerificationCode(user.id, user.mail, user.name);
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      console.warn(`[email:verify] login send failed for user ${user.id}: ${msg}`);
    }
    const verification = await buildVerificationSendMeta(user.id, sendResult);
    throw new AuthError(403, 'EMAIL_NOT_VERIFIED', 'Email must be verified before login', {
      user: toPublicUser(user),
      verification,
      verification_token: signAccessToken(user, VERIFICATION_TOKEN_SCOPE)
    });
  }

  return {
    user: toPublicUser(user),
    accessToken: signAccessToken(user)
  };
}

async function findLoginUser(usernameOrMail: string, password: string): Promise<UserRow | null> {
  const usernameMatch = await authRepository.findByUsername(usernameOrMail);
  if (usernameMatch?.password_hash) {
    const passwordMatches = await bcrypt.compare(password, usernameMatch.password_hash);
    return passwordMatches ? usernameMatch : null;
  }

  const mailMatches = await authRepository.findByMail(usernameOrMail);
  for (const candidate of mailMatches) {
    if (!candidate.password_hash) {
      continue;
    }
    if (await bcrypt.compare(password, candidate.password_hash)) {
      return candidate;
    }
  }
  return null;
}

// Emite un access token completo para un usuario ya validado (p. ej. tras
// confirmar el código de verificación con un token acotado).
export async function issueAccessTokenForUserId(userId: string): Promise<string | null> {
  const user = await authRepository.findById(userId);
  if (!user) {
    return null;
  }
  return signAccessToken(user);
}

export async function getUserFromToken(token: string): Promise<PublicUser> {
  const payload = verifyAccessToken(token);
  if (payload.scope) {
    // Un token acotado (p. ej. email_verification) no habilita el resto de la API.
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid token');
  }
  const user = await authRepository.findById(payload.sub);

  if (!user) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid token');
  }

  return toPublicUser(user);
}

// Acepta tanto un access token completo como el token acotado de verificación.
export async function getUserFromVerificationCapableToken(token: string): Promise<PublicUser> {
  const payload = verifyAccessToken(token);
  if (payload.scope && payload.scope !== VERIFICATION_TOKEN_SCOPE) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid token');
  }
  const user = await authRepository.findById(payload.sub);

  if (!user) {
    throw new AuthError(401, 'INVALID_CREDENTIALS', 'Invalid token');
  }

  return toPublicUser(user);
}
