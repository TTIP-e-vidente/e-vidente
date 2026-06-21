import { EmailMessage } from '../email.types';
import {
  bodyDivider,
  bodyHighlight,
  bodyParagraph,
  buildStreakEmailCtas,
  buildTextLines,
  emailSignOff,
  escapeHtml,
  formatDayLabel,
  GAME_EMAIL_THEME,
  NOTIFICATION_OPT_OUT_TEXT,
  streakHero,
  wrapHtml
} from './layout';
import { StreakTemplateContext } from './types';

export function buildStreakLostEmail(context: StreakTemplateContext): EmailMessage {
  const { name, mail, streakCount, playUrl, leaderboardUrl } = context;
  const safeName = escapeHtml(name);
  const dayLabel = formatDayLabel(streakCount);
  const t = GAME_EMAIL_THEME;
  const subject = 'Tu racha se reinició — podés arrancar otra cuando quieras';

  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    `Pasaron varios días sin actividad y tu racha de ${streakCount} ${dayLabel} volvió a cero.`,
    'No pasa nada: cada día es una nueva oportunidad para aprender jugando.',
    ...(playUrl ? ['', `Jugar: ${playUrl}`] : []),
    ...(leaderboardUrl ? [`Ver ranking: ${leaderboardUrl}`] : []),
    '',
    NOTIFICATION_OPT_OUT_TEXT,
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: 'Tu racha se reinició',
    subtitle: 'Siempre podés volver a empezar',
    preheader: `${name}, tu racha volvió a cero. Hoy podés arrancar una nueva desde el juego.`,
    headerIcon: 'streak',
    includeNotificationOptOut: true,
    bodyHtml: [
      bodyParagraph(
        `Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>,`
      ),
      streakHero(streakCount, 'lost'),
      bodyHighlight(
        `Pasaron varios días sin actividad y tu racha de <strong>${streakCount} ${dayLabel}</strong> volvió a cero.`
      ),
      bodyParagraph(
        'No pasa nada: cada partida suma experiencia y aprendizaje. Hoy es un buen día para empezar una racha nueva.'
      ),
      bodyDivider(),
      buildStreakEmailCtas(playUrl, leaderboardUrl),
      emailSignOff()
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
