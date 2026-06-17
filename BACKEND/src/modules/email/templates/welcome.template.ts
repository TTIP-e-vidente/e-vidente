import { EmailMessage } from '../email.types';
import {
  bodyHighlight,
  bodyParagraph,
  buildTextLines,
  ctaButton,
  escapeHtml,
  GAME_EMAIL_THEME,
  streakBadge,
  wrapHtml
} from './layout';
import { WelcomeTemplateContext } from './types';

export function buildWelcomeEmail(context: WelcomeTemplateContext): EmailMessage {
  const { name, mail } = context;
  const safeName = escapeHtml(name);
  const t = GAME_EMAIL_THEME;
  const subject = '¡Listo! Tu cuenta en E-VIDENTE ya está creada';

  const textContent = buildTextLines([
    `¡Hola ${name}! 🎉`,
    '',
    'Creaste tu cuenta correctamente en E-VIDENTE.',
    'Ya podés entrar al juego, sumar experiencia y empezar tu racha diaria.',
    '',
    'Aprender sobre restricciones alimentarias nunca fue tan entretenido.',
    '¡Que disfrutes el camino!',
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: '¡Bienvenido/a!',
    subtitle: 'Tu cuenta está lista para jugar',
    headerEmoji: '✨',
    headerScheme: 'green',
    bodyHtml: [
      bodyParagraph(
        `¡Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>! Nos alegra que estés acá.`
      ),
      bodyHighlight(
        `Ya podés entrar al juego, sumar experiencia y empezar tu <strong>racha diaria</strong>.`
      ),
      bodyParagraph(
        'Aprender sobre restricciones alimentarias nunca fue tan entretenido. 🥗'
      ),
      ctaButton('¡Empezar a jugar!', t.primaryGreen)
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
