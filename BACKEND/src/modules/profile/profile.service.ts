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
import { sendVerificationCode } from '../email/email.verification.service';
import { sendTransactionalEmail } from '../email/email.client';
import { buildEmailMessage } from '../email/templates';

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

export interface UpdatePlayerMeInput {
  name?: unknown;
  mail?: unknown;
  birth_date?: unknown;
  email_notifications_enabled?: unknown;
}

function asTrimmedString(value: unknown): string | null {
  return typeof value === 'string' ? value.trim() : null;
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

export async function updatePlayerMe(
  userId: string,
  input: UpdatePlayerMeInput
): Promise<PlayerMeResponse> {
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

  const client = await pool.connect();
  // Capturar el mail actual antes de actualizarlo para notificar al mail viejo
  let oldMail: string | null = null;
  if (validatedMail !== undefined && validatedMail !== null) {
    const currentUser = await userRepository.findPublicUserById(userId);
    if (currentUser?.mail && currentUser.mail !== validatedMail) {
      oldMail = currentUser.mail;
    }
  }
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

    const updatedUser = await userRepository.updateUserProfile(client, userId, updates);
    if (!updatedUser) {
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

  // Si el mail cambió a uno válido, enviar código de verificación al nuevo mail
  if (validatedMail) {
    const updatedUser = await userRepository.findPublicUserById(userId);
    if (updatedUser) {
      void sendVerificationCode(userId, validatedMail, updatedUser.name).catch((error) => {
        const msg = error instanceof Error ? error.message : String(error);
        console.warn(`[email:verify] post-mail-update send failed for user ${userId}: ${msg}`);
      });
      // Notificar al mail viejo por seguridad
      if (oldMail) {
        const message = buildEmailMessage('mail_changed', {
          name: updatedUser.name,
          oldMail,
          newMail: validatedMail
        });
        void sendTransactionalEmail(message, { templateKey: 'mail_changed' }).catch((error) => {
          const msg = error instanceof Error ? error.message : String(error);
          console.warn(`[email:mail_changed] notify old mail failed for user ${userId}: ${msg}`);
        });
      }
    }
  }

  return getPlayerMe(userId);
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
