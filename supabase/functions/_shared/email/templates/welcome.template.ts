import { EmailMessage } from '../email-types.ts';
import {
  bodyDivider,
  bodyHighlight,
  bodyParagraph,
  buildTextLines,
  buildWelcomeEmailCtas,
  emailSignOff,
  escapeHtml,
  featureCardRow,
  GAME_EMAIL_THEME,
  wrapHtml
} from './layout.ts';
import { WelcomeTemplateContext } from './types.ts';

export function buildWelcomeEmail(context: WelcomeTemplateContext): EmailMessage {
  const { name, mail, playUrl, leaderboardUrl } = context;
  const safeName = escapeHtml(name);
  const t = GAME_EMAIL_THEME;
  const subject = 'Mail verificado';

  const textContent = buildTextLines([
    `¡Hola ${name}!`,
    '',
    'Confirmaste tu mail correctamente.',
    'Ya podés entrar al juego, sumar experiencia y empezar tu racha diaria.',
    '',
    'Aprender sobre restricciones alimentarias nunca fue tan entretenido.',
    '¡Que disfrutes el camino!',
    ...(playUrl ? ['', `Abrí el juego acá: ${playUrl}`] : []),
    ...(leaderboardUrl ? ['', `Ver el ranking global: ${leaderboardUrl}`] : []),
    '',
    '— Equipo E-VIDENTE'
  ]);

  const ctaHtml = buildWelcomeEmailCtas(playUrl, leaderboardUrl);

  const htmlContent = wrapHtml({
    headline: 'Mail verificado',
    subtitle: 'Tu cuenta está lista',
    preheader: `${name}, tu cuenta en E-VIDENTE ya está activa. Entrá al juego y compite en el ranking.`,
    headerIcon: 'welcome',
    bodyHtml: [
      bodyParagraph(
        `¡Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>! Gracias por confirmar tu mail.`
      ),
      bodyHighlight(
        'Tu cuenta está <strong>activa</strong>. Ya podés sumar experiencia, completar lecciones y ver tu <strong>puesto en el ranking</strong>.'
      ),
      featureCardRow([
        { icon: 'play', title: 'Jugar', text: 'Entrá y completá partidas cortas' },
        { icon: 'xp', title: 'Experiencia', text: 'Sumá XP con cada lección' },
        { icon: 'streak', title: 'Racha', text: 'Jugá cada día para mantenerla' }
      ]),
      bodyDivider(),
      bodyParagraph('Aprender sobre restricciones alimentarias nunca fue tan entretenido.'),
      ctaHtml,
      emailSignOff()
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
