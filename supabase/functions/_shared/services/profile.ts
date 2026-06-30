import { withTransaction } from '../db.ts';
import { PlayerError } from '../player-errors.ts';
import {
  isValidEmail,
  parseBirthDateInput,
} from '../validators.ts';
import type { UpdateUserProfileInput } from '../types/player.ts';
import * as profileRepository from '../repositories/profile.ts';
import * as streakRepository from '../repositories/streak.ts';
import * as userRepository from '../repositories/user.ts';
import { toPublicProfile } from '../mappers/player.ts';
import { toPublicStreak } from '../mappers/player.ts';
import { toPublicUser } from '../mappers/player.ts';
import type { PublicProfile, PublicStreak, PublicUser } from '../mappers/player.ts';
import {
  getVerificationConfig,
  getVerificationCooldownRemainingSeconds,
  sendVerificationCode,
  type SendVerificationResult,
} from '../verification.ts';
import { sendMailChangedEmail } from './mail-changed.ts';

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
  target_mail?: string;
  message?: string;
}

export interface UpdatePlayerMeResponse extends PlayerMeResponse {
  verification?: ProfileVerificationMeta;
}

function asTrimmedString(value: unknown): string | null {
  return typeof value === 'string' ? value.trim() : null;
}

function normalizeMail(value: string | null | undefined): string | null {
  if (value == null) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed.toLowerCase() : null;
}

function parseEmailNotificationsEnabled(value: unknown): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') return true;
    if (normalized === 'false' || normalized === '0') return false;
  }
  throw new PlayerError(400, 'INVALID_BODY', 'email_notifications_enabled must be a boolean');
}

async function buildVerificationMeta(
  userId: string,
  sendResult: ProfileVerificationSendStatus,
  targetMail?: string | null,
): Promise<ProfileVerificationMeta> {
  const trimmedTarget = targetMail?.trim() ?? '';
  if (sendResult === 'sent') {
    return {
      mail_changed: true,
      code_send_status: sendResult,
      cooldown_seconds: getVerificationConfig().cooldownSeconds,
      ...(trimmedTarget
        ? { target_mail: trimmedTarget, message: `Código enviado a ${trimmedTarget}. Revisá spam.` }
        : {}),
    };
  }
  if (sendResult === 'rate_limited') {
    return {
      mail_changed: true,
      code_send_status: sendResult,
      cooldown_seconds: await getVerificationCooldownRemainingSeconds(userId),
      ...(trimmedTarget ? { target_mail: trimmedTarget } : {}),
    };
  }
  return {
    mail_changed: true,
    code_send_status: sendResult,
    cooldown_seconds: 0,
    ...(trimmedTarget ? { target_mail: trimmedTarget } : {}),
  };
}

export async function getPlayerMe(userId: string): Promise<PlayerMeResponse> {
  return await withTransaction(async (client) => {
    const user = await userRepository.findPublicUserByIdOnClient(client, userId);
    if (!user) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }

    const profile = await profileRepository.ensureProfile(client, userId);
    let streak = await streakRepository.getStreakByUserId(client, userId);
    if (!streak) {
      streak = await streakRepository.ensureStreak(client, userId, profile.id);
    }

    return {
      user: toPublicUser(user),
      profile: toPublicProfile(profile),
      streak: toPublicStreak(streak),
    };
  });
}

export async function updatePlayerMe(
  userId: string,
  input: Record<string, unknown>,
): Promise<UpdatePlayerMeResponse> {
  const hasName = Object.prototype.hasOwnProperty.call(input, 'name');
  const hasMail = Object.prototype.hasOwnProperty.call(input, 'mail');
  const hasBirthDate = Object.prototype.hasOwnProperty.call(input, 'birth_date');
  const hasEmailNotifications = Object.prototype.hasOwnProperty.call(
    input,
    'email_notifications_enabled',
  );

  if (!hasName && !hasMail && !hasBirthDate && !hasEmailNotifications) {
    throw new PlayerError(
      400,
      'INVALID_BODY',
      'At least one of name, mail, birth_date or email_notifications_enabled is required',
    );
  }

  const userBeforeUpdate = await userRepository.findPublicUserById(userId);
  if (!userBeforeUpdate) {
    throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
  }
  const previousMail = normalizeMail(userBeforeUpdate.mail);
  const oldMailRaw = userBeforeUpdate.mail?.trim() ?? '';

  const updates: UpdateUserProfileInput = {};

  if (hasName) {
    const name = asTrimmedString(input.name);
    if (!name) throw new PlayerError(400, 'INVALID_BODY', 'name cannot be empty');
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
      input.email_notifications_enabled,
    );
  }

  if (updates.email_notifications_enabled === true) {
    const mailWillChange = validatedMail !== undefined &&
      normalizeMail(validatedMail) !== previousMail;
    const hasMailValue = Boolean(
      (validatedMail !== undefined ? validatedMail : userBeforeUpdate.mail)?.trim(),
    );
    const staysVerified = !mailWillChange && Boolean(userBeforeUpdate.mail_verified_at);
    if (!hasMailValue || !staysVerified) {
      throw new PlayerError(
        422,
        'MAIL_NOT_VERIFIED',
        'Verify your email before enabling streak reminders',
      );
    }
  }

  await withTransaction(async (client) => {
    if (validatedMail !== undefined) {
      if (validatedMail !== null) {
        const existingMail = await userRepository.findByMailExcludingUserId(
          client,
          validatedMail,
          userId,
        );
        if (existingMail) {
          throw new PlayerError(409, 'DUPLICATE_MAIL', 'mail already exists');
        }
      }
      updates.mail = validatedMail;
      await client.queryObject(
        `
          UPDATE email_verification_codes
          SET used_at = now()
          WHERE user_id = $1 AND used_at IS NULL;
        `,
        [userId],
      );
    }

    const updatedUserRow = await userRepository.updateUserProfile(client, userId, updates);
    if (!updatedUserRow) {
      throw new PlayerError(401, 'INVALID_TOKEN', 'Invalid token');
    }
  });

  const mailChanged = validatedMail !== undefined &&
    normalizeMail(validatedMail) !== previousMail;

  let verification: ProfileVerificationMeta | undefined;
  if (mailChanged && validatedMail) {
    const sendResult = await sendVerificationCode(userId, validatedMail, userBeforeUpdate.name);
    verification = await buildVerificationMeta(userId, sendResult, validatedMail);
    if (oldMailRaw) {
      void sendMailChangedEmail({
        userId,
        name: userBeforeUpdate.name,
        oldMail: oldMailRaw,
        newMail: validatedMail,
      });
    }
  } else if (mailChanged && validatedMail === null) {
    verification = {
      mail_changed: true,
      code_send_status: 'not_requested',
      cooldown_seconds: 0,
    };
  }

  const response = await getPlayerMe(userId);
  return verification ? { ...response, verification } : response;
}
