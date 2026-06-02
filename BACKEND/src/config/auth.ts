import dotenv from 'dotenv';

dotenv.config();

export const authConfig = {
  jwtSecret: process.env.JWT_SECRET ?? '',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '1h',
  bcryptSaltRounds: Number.parseInt(process.env.BCRYPT_SALT_ROUNDS ?? '10', 10)
};

export function assertAuthConfig(): void {
  if (!authConfig.jwtSecret) {
    throw new Error('JWT_SECRET is required');
  }
}
