import { EmailMessage, EmailTemplateKey } from '../email.types';
import { EmailVerificationTemplateContext } from './email-verification.template';
import { MailChangedTemplateContext } from './mail-changed.template';

export interface WelcomeTemplateContext {
  name: string;
  mail: string;
  playUrl?: string;
  /** Enlace directo al ranking dentro del juego. */
  leaderboardUrl?: string;
}

export interface AccountVerifiedTemplateContext {
  name: string;
  mail: string;
  playUrl?: string;
  /** Enlace directo al ranking dentro del juego. */
  leaderboardUrl?: string;
}

export interface StreakTemplateContext {
  name: string;
  mail: string;
  streakCount: number;
  /** URL base del juego (itch, web, etc.). */
  playUrl?: string;
  /** Enlace directo al ranking dentro del juego. */
  leaderboardUrl?: string;
}

export type TemplateContextByKey = {
  welcome: WelcomeTemplateContext;
  account_verified: AccountVerifiedTemplateContext;
  streak_at_risk: StreakTemplateContext;
  streak_lost: StreakTemplateContext;
  email_verification: EmailVerificationTemplateContext;
  mail_changed: MailChangedTemplateContext;
};

export interface EmailTemplateDefinition<K extends EmailTemplateKey = EmailTemplateKey> {
  key: K;
  title: string;
  description: string;
  sampleContext: () => TemplateContextByKey[K];
  build: (context: TemplateContextByKey[K]) => EmailMessage;
}

export interface EmailTemplatePreviewParams {
  name?: string;
  mail?: string;
  streak_count?: number;
}
