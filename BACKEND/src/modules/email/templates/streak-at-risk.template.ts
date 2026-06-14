import { EmailMessage } from '../email.types';
import {
  bodyHighlight,
  bodyParagraph,
  buildTextLines,
  escapeHtml,
  formatDayLabel,
  NOTIFICATION_OPT_OUT_TEXT,
  wrapHtml
} from './layout';
import { StreakTemplateContext } from './types';

export function buildStreakAtRiskEmail(context: StreakTemplateContext): EmailMessage {
  const { name, mail, streakCount } = context;
  const safeName = escapeHtml(name);
  const dayLabel = formatDayLabel(streakCount);
  const subject = 'Tu racha está en riesgo — jugá hoy en E-VIDENTE';
  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    `Tu racha de ${streakCount} ${dayLabel} sigue viva, pero hoy todavía no registraste actividad.`,
    'Entrá al juego y completá una partida para mantenerla.',
    '',
    NOTIFICATION_OPT_OUT_TEXT,
    '',
    'Equipo E-VIDENTE'
  ]);
  const htmlContent = wrapHtml({
    headline: 'Tu racha está en riesgo',
    subtitle: 'Jugá hoy para mantenerla',
    includeNotificationOptOut: true,
    bodyHtml: [
      bodyParagraph(`Hola <strong style="color: #42785e;">${safeName}</strong>,`),
      bodyHighlight(
        `Tu racha de <strong style="color: #42785e;">${streakCount} ${dayLabel}</strong> sigue viva, pero hoy todavía no registraste actividad.`
      ),
      bodyParagraph('Entrá al juego y completá una partida para mantenerla.')
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
