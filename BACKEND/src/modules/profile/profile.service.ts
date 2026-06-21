/**
 * PROFILE del MER.
 *
 * Responsabilidad:
 * - Obtener y preparar el perfil del jugador.
 * - Coordinar datos de USER, STREAK y progreso general si corresponde.
 *
 * No debe:
 * - Exponer password_hash.
 * - Ejecutar SQL directo fuera del repository.
 */
import { pool } from '../../config/database';
import { AppError } from '../../shared/errors/app_error';
import { isValidEmail } from '../../shared/validation/validators';
import { parseBirthDateInput } from '../../shared/validation/birth_date';
import { PublicUser, toPublicUser } from '../user/user.mapper';
import * as userRepository from '../user/user.repository';
import * as profileRepository from './profile.repository';
import * as streakRepository from '../streak/streak.repository';
import { PublicProfile, toPublicProfile } from './profile.mapper';
import { PublicStreak, toPublicStreak } from '../streak/streak.mapper';
import {
  getVerificationConfig,
  getVerificationCooldownRemainingSeconds,
  sendVerificationCode,
  SendVerificationResult
} from '../email/email.verification.service';
import { sendMailChangedEmail } from '../email/email.service';

export class PlayerError extends AppError {
  constructor(statusCode: number, code: string, message: string) {
    super(statusCode, code, message);
  }
}

export interface PlayerMeResponse {
  user: PublicUser;
  profile: PublicProfile;
  streak: PublicStreak;
}

export type ProfileVerificationSendStatus = SendVerificationResult | 'not_requested';

export interface ProfileVerificationMeta {
  mail_changed: boolean;
  code_send_status: ProfileVerificationSendStatus;
  cooldown_seconds: number;
}

export interface UpdatePlayerMeResponse extends PlayerMeResponse {
  verification?: ProfileVerificationMeta;
}

export interface UpdatePlayerMeInput {
  name?: unknown;
  mail?: unknown;
  birth_date?: unknown;
  email_notifications_enabled?: unknown;
}

function asTrimmedString(value: unknown): string | null {
  return typeof value === 'string' ? value.trim() : null;
}

function normalizeMail(value: string | null | undefined): string | null {
  if (value == null) {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed.toLowerCase() : null;
}

function parseEmailNotificationsEnabled(value: unknown): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') {
      return true;
    }
    if (normalized === 'false' || normalized === '0') {
      return false;
    }
  }
  throw new PlayerError(
    400,
    'INVALID_BODY',
    'email_notifications_enabled must be a boolean'
  );
}

async function buildVerificationMeta(
  userId: string,
  sendResult: ProfileVerificationSendStatus
): Promise<ProfileVerificationMeta> {
  if (sendResult === 'sent') {
    return {
      mail_changed: true,
      code_send_status: sendResult,
      cooldown_seconds: getVerificationConfig().cooldownSeconds
    };
  }

  if (sendResult === 'rate_limited') {
    return {
      mail_changed: true,
      code_send_status: sendResult,
      cooldown_seconds: await getVerificationCooldownRemainingSeconds(userId)
    };
  }

  return {
    mail_changed: true,
    code_send_status: sendResult,
    cooldown_seconds: 0
  };
}

export async function updatePlayerMe(
  userId: string,
  input: UpdatePlayerMeInput
): Promise<UpdatePlayerMeResponse> {
  const hasName = Object.prototype.hasOwnProperty.call(input, 'name');
  const hasMail = Object.prototype.hasOwnProperty.call(input, 'mail');
  const hasBirthDate = Object.prototype.hasOwnProperty.call(input, 'birth_date');
  const hasEmailNotifications = Object.prototype.hasOwnProperty.call(
    input,
    'email_notifications_enabled'
  );

  if (!hasName && !hasMail && !hasBirthDate && !hasEmailNotifications) {
    throw new PlayerError(
      400,
      'INVALID_BODY',
      'At least one of name, mail, birth_date or email_notifications_enabled is required'
    );
  }

  const userBeforeUpdate = await userRepository.findPublicUserById(userId);
  if (!userBeforeUpdate) {
    throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
  }
  const previousMail = normalizeMail(userBeforeUpdate.mail);

  const updates: userRepository.UpdateUserProfileInput = {};

  if (hasName) {
    const name = asTrimmedString(input.name);
    if (!name) {
      throw new PlayerError(400, 'INVALID_BODY', 'name cannot be empty');
    }
    updates.name = name;
  }

  let validatedMail: string | null | undefined;
  if (hasMail) {
    if (input.mail === null || input.mail === undefined) {
      validatedMail = null;
    } else {
      const mail = asTrimmedString(input.mail);
      if (!mail) {
        validatedMail = null;
      } else if (!isValidEmail(mail)) {
        throw new PlayerError(400, 'INVALID_BODY', 'mail must be a valid email');
      } else {
        validatedMail = mail;
      }
    }
  }

  if (hasBirthDate) {
    if (input.birth_date === null || input.birth_date === undefined) {
      updates.birth_date = null;
    } else {
      const birthDate = parseBirthDateInput(input.birth_date);
      if (birthDate === undefined) {
        throw new PlayerError(400, 'INVALID_BODY', 'birth_date must be a valid ISO date (YYYY-MM-DD)');
      }
      updates.birth_date = birthDate;
    }
  }

  if (hasEmailNotifications) {
    updates.email_notifications_enabled = parseEmailNotificationsEnabled(
      input.email_notifications_enabled
    );
  }

  if (updates.email_notifications_enabled === true) {
    const mailWillChange = validatedMail !== undefined &&
      normalizeMail(validatedMail) !== previousMail;
    const hasMail = Boolean(
      (validatedMail !== undefined ? validatedMail : userBeforeUpdate.mail)?.trim()
    );
    const staysVerified = !mailWillChange && Boolean(userBeforeUpdate.mail_verified_at);
    if (!hasMail || !staysVerified) {
      throw new PlayerError(
        422,
        'MAIL_NOT_VERIFIED',
        'Verify your email before enabling streak reminders'
      );
    }
  }

  let oldMail: string | null = null;
  if (validatedMail !== undefined && validatedMail !== null) {
    if (previousMail && previousMail !== normalizeMail(validatedMail)) {
      oldMail = userBeforeUpdate.mail?.trim() ?? null;
    }
  }

  const client = await pool.connect();
  let updatedUserRow: Awaited<ReturnType<typeof userRepository.updateUserProfile>> = null;
  try {
    await client.query('BEGIN');

    if (validatedMail !== undefined) {
      if (validatedMail !== null) {
        const existingMail = await userRepository.findByMailExcludingUserId(
          client, validatedMail, userId
        );
        if (existingMail) {
          throw new PlayerError(409, 'DUPLICATE_MAIL', 'mail already exists');
        }
      }
      updates.mail = validatedMail;
    }

    updatedUserRow = await userRepository.updateUserProfile(client, userId, updates);
    if (!updatedUserRow) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }
    await client.query('COMMIT');
  } catch (error: unknown) {
    await client.query('ROLLBACK');
    if (error instanceof PlayerError) throw error;
    const pgCode = (error as Record<string, unknown>)?.code;
    if (pgCode === '23505') {
      throw new PlayerError(409, 'DUPLICATE_MAIL', 'mail already exists');
    }
    throw error;
  } finally {
    client.release();
  }

  const mailChanged =
    validatedMail !== undefined &&
    normalizeMail(validatedMail) !== previousMail;

  let verification: ProfileVerificationMeta | undefined;

  if (mailChanged && validatedMail && updatedUserRow) {
    const sendResult = await sendVerificationCode(userId, validatedMail, updatedUserRow.name);
    verification = await buildVerificationMeta(userId, sendResult);

    if (oldMail) {
      void sendMailChangedEmail({
        userId,
        name: updatedUserRow.name,
        oldMail,
        newMail: validatedMail
      });
    }
  } else if (mailChanged && validatedMail === null) {
    verification = {
      mail_changed: true,
      code_send_status: 'not_requested',
      cooldown_seconds: 0
    };
  }

  const response = await getPlayerMe(userId);
  return verification ? { ...response, verification } : response;
}

export async function getPlayerMe(userId: string): Promise<PlayerMeResponse> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await userRepository.findPublicUserById(userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await profileRepository.ensureProfile(client, userId);
    let streak = await streakRepository.getStreakByUserId(client, userId);
    if (!streak) {
      streak = await streakRepository.ensureStreak(client, userId, profile.id);
    }
    await client.query('COMMIT');

    return {
      user: toPublicUser(user),
      profile: toPublicProfile(profile),
      streak: toPublicStreak(streak)
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
