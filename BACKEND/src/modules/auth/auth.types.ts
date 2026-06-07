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
}

export interface AuthResponse {
  user: PublicUser;
  accessToken: string;
}

export interface RegisterInput {
  username?: unknown;
  name?: unknown;
  mail?: unknown;
  password?: unknown;
  birth_date?: unknown;
}

export interface LoginInput {
  usernameOrMail?: unknown;
  password?: unknown;
}

export interface UserRow {
  id: string;
  username: string;
  email: string | null;
  password_hash: string | null;
  display_name: string | null;
  birth_date: Date | string | null;
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
  birthDate: string | null;
}
