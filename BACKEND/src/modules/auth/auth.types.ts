export type AuthErrorCode =
  | 'INVALID_BODY'
  | 'INVALID_CREDENTIALS'
  | 'DUPLICATE_USERNAME'
  | 'DUPLICATE_MAIL'
  | 'EMAIL_NOT_VERIFIED';

export interface PublicUser {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  birth_date: string | null;
  email_notifications_enabled: boolean;
  mail_verified_at: string | null;
}

export type AuthVerificationSendStatus =
  | 'sent'
  | 'skipped'
  | 'dev_console'
  | 'rate_limited'
  | 'no_mail'
  | 'send_failed'
  | 'not_requested';

export interface AuthVerificationMeta {
  code_send_status: AuthVerificationSendStatus;
  cooldown_seconds: number;
  message: string;
  expires_minutes: number;
}

export interface AuthResponse {
  user: PublicUser;
  accessToken: string;
  verification?: AuthVerificationMeta;
}

export interface RegisterInput {
  username?: unknown;
  name?: unknown;
  mail?: unknown;
  password?: unknown;
  birth_date?: unknown;
  accept_email_notifications?: unknown;
  request_email_verification?: unknown;
}

export interface LoginInput {
  usernameOrMail?: unknown;
  password?: unknown;
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

export interface CreateUserInput {
  username: string;
  name: string;
  mail: string | null;
  passwordHash: string;
  birthDate: string | null;
  emailNotificationsEnabled: boolean;
}
