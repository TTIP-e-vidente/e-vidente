import { EmailMessage } from '../email-types.ts';
import {
  bodyDivider,
  bodyHighlight,
  bodyParagraph,
  bodyWarmPanel,
  buildStreakEmailCtas,
  buildTextLines,
  emailSignOff,
  escapeHtml,
  formatDayLabel,
  GAME_EMAIL_THEME,
  NOTIFICATION_OPT_OUT_TEXT,
  streakHero,
  wrapHtml
} from './layout.ts';
import { StreakTemplateContext } from './types.ts';

export function buildStreakLastChanceEmail(context: StreakTemplateContext): EmailMessage {
  const { name, mail, streakCount, playUrl, leaderboardUrl } = context;
  const safeName = escapeHtml(name);
  const dayLabel = formatDayLabel(streakCount);
  const t = GAME_EMAIL_THEME;
  const subject = `Estás a 1 hora de perder tu racha de ${streakCount} ${dayLabel}`;

  const textContent = buildTextLines([
    `¡Hola ${name}!`,
    '',
    `Estás a 1 hora de perder tu racha de ${streakCount} ${dayLabel}. Por favor, volvé a jugar.`,
    'Una partida corta alcanza para mantenerla viva hasta mañana.',
    ...(playUrl ? ['', `Jugar: ${playUrl}`] : []),
    ...(leaderboardUrl ? [`Ver ranking: ${leaderboardUrl}`] : []),
    '',
    NOTIFICATION_OPT_OUT_TEXT,
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: 'Estás a 1 hora de perder tu racha',
    subtitle: `${streakCount} ${dayLabel} · por favor, volvé`,
    preheader: `${name}, en 1 hora se pierde tu racha de ${streakCount} ${dayLabel} si no jugás.`,
    includeNotificationOptOut: true,
    bodyHtml: [
      bodyParagraph(
        `¡Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>!`
      ),
      streakHero(streakCount, 'last_chance'),
      bodyWarmPanel(
        'Última hora',
        `Estás a 1 hora de perder tu racha de <strong>${streakCount} ${dayLabel}</strong>. Por favor, volvé a jugar antes de que termine el día.`
      ),
      bodyHighlight(
        'Una partida corta alcanza. Entrá ahora y mantené viva tu progreso diario.'
      ),
      bodyDivider(),
      buildStreakEmailCtas(playUrl, leaderboardUrl),
      emailSignOff()
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
