import type { EmailMessage } from './email-types.ts';
import { getEmailConfig } from './email-config.ts';
import { buildLeaderboardDeepLink } from './templates/app-deep-links.ts';
import { buildEmailVerificationEmail } from './templates/email-verification.template.ts';
import { buildStreakAtRiskEmail as buildStreakAtRiskEmailTemplate } from './templates/streak-at-risk.template.ts';
import { buildStreakLostEmail as buildStreakLostEmailTemplate } from './templates/streak-lost.template.ts';
import type { StreakTemplateContext } from './templates/types.ts';
import { buildWelcomeEmail as buildWelcomeEmailTemplate } from './templates/welcome.template.ts';

function buildStreakMessageContext(
  name: string,
  mail: string,
  streakCount: number,
): StreakTemplateContext {
  const { appPlayUrl } = getEmailConfig();
  const playUrl = appPlayUrl.length > 0 ? appPlayUrl : undefined;
  const leaderboardUrl = playUrl ? buildLeaderboardDeepLink(playUrl, 'global_xp') : undefined;

  return {
    name: name.trim() || 'Jugador',
    mail: mail.trim(),
    streakCount: Math.max(1, streakCount),
    playUrl,
    leaderboardUrl,
  };
}

export function buildVerificationEmail(input: {
  name: string;
  mail: string;
  code: string;
  expiresMinutes: number;
}): EmailMessage {
  return buildEmailVerificationEmail(input);
}

export function buildWelcomeEmail(input: { name: string; mail: string }): EmailMessage {
  const { appPlayUrl } = getEmailConfig();
  const playUrl = appPlayUrl.length > 0 ? appPlayUrl : undefined;
  const leaderboardUrl = playUrl ? buildLeaderboardDeepLink(playUrl, 'global_xp') : undefined;

  return buildWelcomeEmailTemplate({
    name: input.name,
    mail: input.mail,
    playUrl,
    leaderboardUrl,
  });
}

export function buildStreakAtRiskEmail(
  name: string,
  mail: string,
  streakCount: number,
): EmailMessage {
  return buildStreakAtRiskEmailTemplate(
    buildStreakMessageContext(name, mail, streakCount),
  );
}

export function buildStreakLostEmail(
  name: string,
  mail: string,
  streakCount: number,
): EmailMessage {
  return buildStreakLostEmailTemplate(
    buildStreakMessageContext(name, mail, streakCount),
  );
}
