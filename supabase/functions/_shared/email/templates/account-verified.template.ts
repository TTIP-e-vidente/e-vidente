import { EmailMessage } from '../email-types.ts';
import {
  bodyDivider,
  bodyHighlight,
  bodyParagraph,
  buildTextLines,
  buildWelcomeEmailCtas,
  emailSignOff,
  escapeHtml,
  GAME_EMAIL_THEME,
  wrapHtml
} from './layout.ts';
import { AccountVerifiedTemplateContext } from './types.ts';

// Mail transaccional post-verificación. Distinto del welcome: acá el foco es
// confirmar que el correo quedó verificado y la cuenta activa.
export function buildAccountVerifiedEmail(context: AccountVerifiedTemplateContext): EmailMessage {
  const { name, mail, playUrl, leaderboardUrl } = context;
  const safeName = escapeHtml(name);
  const t = GAME_EMAIL_THEME;
  const subject = 'Tu correo fue verificado';

  const textContent = buildTextLines([
    `¡Hola ${name}!`,
    '',
    'Tu correo fue verificado.',
    'Tu cuenta ya está activa: tu progreso, tu racha y tu avatar quedan guardados en la nube.',
    '',
    'Cuando quieras, volvé al juego y seguí donde lo dejaste.',
    ...(playUrl ? ['', `Abrí el juego acá: ${playUrl}`] : []),
    '',
    '— Equipo E-VIDENTE'
  ]);

  const ctaHtml = buildWelcomeEmailCtas(playUrl, leaderboardUrl);

  const htmlContent = wrapHtml({
    headline: 'Correo verificado',
    subtitle: 'Tu cuenta ya está activa',
    preheader: `${name}, tu correo quedó verificado y tu cuenta en E-VIDENTE ya está activa.`,
    bodyHtml: [
      bodyParagraph(
        `¡Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>! Confirmamos tu correo correctamente.`
      ),
      bodyHighlight(
        'Tu cuenta ya está <strong>activa</strong>. Tu progreso, tu racha y tu avatar quedan guardados en la nube.'
      ),
      bodyDivider(),
      bodyParagraph('Cuando quieras, volvé al juego y seguí donde lo dejaste.'),
      ctaHtml,
      emailSignOff()
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
