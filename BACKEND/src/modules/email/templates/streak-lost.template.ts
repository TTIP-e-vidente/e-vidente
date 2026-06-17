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

export function buildStreakLostEmail(context: StreakTemplateContext): EmailMessage {
  const { name, mail, streakCount } = context;
  const safeName = escapeHtml(name);
  const dayLabel = formatDayLabel(streakCount);
  const t = GAME_EMAIL_THEME;
  const subject = 'Tu racha se reinició — ¡podés arrancar otra cuando quieras!';

  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    `Pasaron varios días sin actividad y tu racha de ${streakCount} ${dayLabel} volvió a cero.`,
    'No pasa nada: cada día es una nueva oportunidad para aprender jugando.',
    '',
    NOTIFICATION_OPT_OUT_TEXT,
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: 'Tu racha se reinició',
    subtitle: 'Siempre podés volver a empezar',
    headerEmoji: '💪',
    headerScheme: 'green',
    includeNotificationOptOut: true,
    bodyHtml: [
      bodyParagraph(
        `Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>,`
      ),
      bodyHighlight(
        `Pasaron varios días sin actividad y tu racha de ` +
        `<strong style="color: ${t.orangeAccent};">${streakCount} ${dayLabel}</strong> volvió a cero.`
      ),
      bodyParagraph(
        'No pasa nada: cada partida que jugás suma experiencia y aprendizaje. ¡Hoy es un buen día para empezar una racha nueva! 🌱'
      ),
      ctaButton('¡Volver a jugar!', t.primaryGreen)
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
