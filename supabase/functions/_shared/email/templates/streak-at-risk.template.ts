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

export function buildStreakAtRiskEmail(context: StreakTemplateContext): EmailMessage {
  const { name, mail, streakCount, playUrl, leaderboardUrl } = context;
  const safeName = escapeHtml(name);
  const dayLabel = formatDayLabel(streakCount);
  const t = GAME_EMAIL_THEME;
  const subject = `Tu racha de ${streakCount} ${dayLabel} sigue en juego — jugá hoy`;

  const textContent = buildTextLines([
    `¡Hola ${name}!`,
    '',
    `Llevás ${streakCount} ${dayLabel} de racha, pero hoy todavía no registramos que hayas jugado.`,
    'Entrá y completá una partida antes de que termine el día para no perderla.',
    ...(playUrl ? ['', `Jugar: ${playUrl}`] : []),
    ...(leaderboardUrl ? [`Ver ranking: ${leaderboardUrl}`] : []),
    '',
    NOTIFICATION_OPT_OUT_TEXT,
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: 'Tu racha está en riesgo',
    subtitle: `${streakCount} ${dayLabel} · jugá hoy para mantenerla`,
    preheader: `${name}, tu racha de ${streakCount} ${dayLabel} puede perderse si no jugás hoy.`,
    headerIcon: 'streak',
    includeNotificationOptOut: true,
    bodyHtml: [
      bodyParagraph(
        `¡Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>!`
      ),
      streakHero(streakCount, 'at_risk'),
      bodyWarmPanel(
        'Último llamado',
        `Hoy todavía no registramos actividad. Tu racha de <strong>${streakCount} ${dayLabel}</strong> se pierde si no completás una partida antes de que termine el día.`
      ),
      bodyHighlight(
        'Una partida corta alcanza. Entrá, juega una lección y mantené viva tu progreso diario.'
      ),
      bodyDivider(),
      buildStreakEmailCtas(playUrl, leaderboardUrl),
      emailSignOff()
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
