import { EmailMessage, EmailTemplateKey } from '../email.types';

export interface WelcomeTemplateContext {
  name: string;
  mail: string;
}

export interface StreakTemplateContext {
  name: string;
  mail: string;
  streakCount: number;
}

export type TemplateContextByKey = {
  welcome: WelcomeTemplateContext;
  streak_at_risk: StreakTemplateContext;
  streak_lost: StreakTemplateContext;
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
