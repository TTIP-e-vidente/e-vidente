import { EmailMessage } from '../email.types';
import { bodyHighlight, bodyParagraph, buildTextLines, escapeHtml, wrapHtml } from './layout';
import { WelcomeTemplateContext } from './types';

export function buildWelcomeEmail(context: WelcomeTemplateContext): EmailMessage {
  const { name, mail } = context;
  const safeName = escapeHtml(name);
  const subject = '¡Bienvenido/a a E-VIDENTE!';
  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    'Tu cuenta en E-VIDENTE fue creada correctamente.',
    'Ya podés empezar a jugar, sumar experiencia y sostener tu racha diaria.',
    '',
    'Nos alegra que estés acá. ¡Que disfrutes el camino!',
    '',
    'Equipo E-VIDENTE'
  ]);
  const htmlContent = wrapHtml({
    headline: '¡Bienvenido/a!',
    subtitle: 'Tu cuenta está lista para jugar',
    bodyHtml: [
      bodyParagraph(`Hola <strong style="color: #42785e;">${safeName}</strong>,`),
      bodyParagraph('Tu cuenta en <strong>E-VIDENTE</strong> fue creada correctamente.'),
      bodyHighlight(
        'Ya podés empezar a jugar, sumar experiencia y sostener tu racha diaria.'
      ),
      bodyParagraph('Nos alegra que estés acá. ¡Que disfrutes el camino!')
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
