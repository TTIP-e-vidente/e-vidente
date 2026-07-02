export type EmailTemplateKey =
  | 'welcome'
  | 'account_verified'
  | 'streak_at_risk'
  | 'streak_lost'
  | 'email_verification'
  | 'mail_changed';

export type EmailDeliveryStatus = 'pending' | 'sent' | 'failed';

export interface EmailRecipient {
  userId: string;
  mail: string;
  name: string;
}

export interface EmailMessage {
  to: string;
  toName: string;
  subject: string;
  htmlContent: string;
  textContent: string;
}

export interface EmailDeliveryRow {
  id: string;
  user_id: string;
  username: string;
  user_mail: string | null;
  template_key: EmailTemplateKey;
  dedupe_key: string;
  recipient_email: string | null;
  subject: string | null;
  status: EmailDeliveryStatus;
  provider_message_id: string | null;
  error_message: string | null;
  attempt_count: number;
  created_at: Date;
  sent_at: Date | null;
  failed_at: Date | null;
}

export interface ListEmailDeliveriesFilters {
  userId?: string;
  templateKey?: EmailTemplateKey;
  status?: EmailDeliveryStatus;
  limit?: number;
}

export interface StreakEmailCandidate {
  userId: string;
  mail: string;
  name: string;
  streakId: string;
  currentCount: number;
  bestCount: number;
  lastActivityDay: string;
}

export interface FailedDeliveryRetryCandidate {
  id: string;
  userId: string;
  templateKey: EmailTemplateKey;
  dedupeKey: string;
  recipientEmail: string;
  attemptCount: number;
}

export interface UserEmailContext {
  userId: string;
  name: string;
  mail: string | null;
}

export interface PendingWelcomeDelivery {
  id: string;
  userId: string;
  recipientEmail: string;
}

export interface UserStreakContext {
  streakId: string;
  currentCount: number;
}
