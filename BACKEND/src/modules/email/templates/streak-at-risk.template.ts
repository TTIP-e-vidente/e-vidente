import { EmailMessage } from '../email.types';
import {
  bodyHighlight,
  bodyParagraph,
  buildTextLines,
  ctaButton,
  escapeHtml,
  formatDayLabel,
  GAME_EMAIL_THEME,
  NOTIFICATION_OPT_OUT_TEXT,
  streakBadge,
  wrapHtml
} from './layout';
import { StreakTemplateContext } from './types';

export function buildStreakAtRiskEmail(context: StreakTemplateContext): EmailMessage {
  const { name, mail, streakCount } = context;
  const safeName = escapeHtml(name);
  const dayLabel = formatDayLabel(streakCount);
  const t = GAME_EMAIL_THEME;
  const subject = `🔥 Tu racha de ${streakCount} ${dayLabel} sigue en juego — jugá hoy`;

  const textContent = buildTextLines([
    `¡Hola ${name}!`,
    '',
    `Llevás ${streakCount} ${dayLabel} de racha, pero hoy todavía no registramos que hayas jugado.`,
    'Entrá y completá una partida antes de que termine el día para no perderla.',
    '',
    NOTIFICATION_OPT_OUT_TEXT,
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: '¡Tu racha está en riesgo!',
    subtitle: `${streakCount} ${dayLabel} · jugá hoy para mantenerla`,
    headerEmoji: '🔥',
    headerScheme: 'green',
    includeNotificationOptOut: true,
    bodyHtml: [
      bodyParagraph(
        `¡Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>!`
      ),
      streakBadge(streakCount),
      bodyHighlight(
        `Hoy todavía no registramos que hayas jugado. ` +
        `Tu racha de <strong>${streakCount} ${dayLabel}</strong> podría perderse si no entrás antes de que termine el día.`
      ),
      bodyParagraph('Completá una partida corta y mantenela activa. ¡Podés hacerlo!'),
      ctaButton('¡Jugar ahora!', t.orangeAccent)
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
