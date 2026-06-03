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
import { UserPublicRow } from '../user/user.types';
import * as userRepository from '../user/user.repository';
import * as profileRepository from './profile.repository';
import * as streakRepository from '../streak/streak.repository';
import { PublicProfile, toPublicProfile } from './profile.mapper';
import { PublicStreak, toPublicStreak } from '../streak/streak.mapper';

export class PlayerError extends AppError {
  constructor(statusCode: number, code: string, message: string) {
    super(statusCode, code, message);
  }
}

export interface PlayerMeResponse {
  user: UserPublicRow;
  profile: PublicProfile;
  streak: PublicStreak;
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
    const streak = await streakRepository.ensureStreak(client, userId, profile.id);
    await client.query('COMMIT');

    return {
      user,
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
