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

export function buildStreakLostEmail(context: StreakTemplateContext): EmailMessage {
  const { name, mail, streakCount } = context;
  const safeName = escapeHtml(name);
  const dayLabel = formatDayLabel(streakCount);
  const subject = 'Se cortó tu racha en E-VIDENTE';
  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    `Pasaron más de un día sin actividad y se cortó tu racha de ${streakCount} ${dayLabel}.`,
    'No pasa nada: siempre podés empezar de nuevo cuando quieras.',
    '',
    NOTIFICATION_OPT_OUT_TEXT,
    '',
    'Equipo E-VIDENTE'
  ]);
  const htmlContent = wrapHtml({
    headline: 'Tu racha se cortó',
    subtitle: 'Siempre podés volver a empezar',
    includeNotificationOptOut: true,
    bodyHtml: [
      bodyParagraph(`Hola <strong style="color: #42785e;">${safeName}</strong>,`),
      bodyHighlight(
        `Pasaron más de un día sin actividad y se cortó tu racha de <strong style="color: #704533;">${streakCount} ${dayLabel}</strong>.`
      ),
      bodyParagraph('No pasa nada: siempre podés empezar de nuevo cuando quieras.')
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
