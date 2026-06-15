import { EmailMessage } from '../email.types';
import { bodyHighlight, bodyParagraph, buildTextLines, escapeHtml, wrapHtml } from './layout';
import { WelcomeTemplateContext } from './types';

export function buildWelcomeEmail(context: WelcomeTemplateContext): EmailMessage {
  const { name, mail } = context;
  const safeName = escapeHtml(name);
  const subject = '¡Listo! Tu cuenta en E-VIDENTE ya está creada';
  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    'Creaste tu cuenta correctamente. Ya podés entrar al juego, sumar experiencia y empezar tu racha diaria.',
    '',
    'Nos alegra que estés acá. ¡Que disfrutes el camino!',
    '',
    'Equipo E-VIDENTE'
  ]);
  const htmlContent = wrapHtml({
    headline: '¡Bienvenido/a a E-VIDENTE!',
    subtitle: 'Tu cuenta está lista para jugar',
    bodyHtml: [
      bodyParagraph(`Hola <strong style="color: #42785e;">${safeName}</strong>,`),
      bodyParagraph('Creaste tu cuenta correctamente.'),
      bodyHighlight(
        'Ya podés entrar al juego, sumar experiencia y empezar tu racha diaria.'
      ),
      bodyParagraph('Nos alegra que estés acá. ¡Que disfrutes el camino!')
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
