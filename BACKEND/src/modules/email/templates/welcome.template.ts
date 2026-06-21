import { EmailMessage } from '../email.types';
import {
  bodyHighlight,
  bodyParagraph,
  buildTextLines,
  ctaButton,
  ctaLink,
  escapeHtml,
  GAME_EMAIL_THEME,
  streakBadge,
  wrapHtml
} from './layout';
import { WelcomeTemplateContext } from './types';

export function buildWelcomeEmail(context: WelcomeTemplateContext): EmailMessage {
  const { name, mail, playUrl } = context;
  const safeName = escapeHtml(name);
  const t = GAME_EMAIL_THEME;
  const subject = '¡Listo! Tu cuenta en E-VIDENTE ya está creada';
  const ctaLines: string[] = [];
  if (playUrl) {
    ctaLines.push('', `Abrí el juego acá: ${playUrl}`);
  }

  const textContent = buildTextLines([
    `¡Hola ${name}! 🎉`,
    '',
    'Creaste tu cuenta correctamente en E-VIDENTE.',
    'Ya podés entrar al juego, sumar experiencia y empezar tu racha diaria.',
    '',
    'Aprender sobre restricciones alimentarias nunca fue tan entretenido.',
    '¡Que disfrutes el camino!',
    ...ctaLines,
    '',
    '— Equipo E-VIDENTE'
  ]);

  const ctaHtml = playUrl
    ? ctaLink('¡Empezar a jugar!', playUrl, t.primaryGreen)
    : ctaButton('¡Empezar a jugar!', t.primaryGreen);

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
      ctaHtml
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
