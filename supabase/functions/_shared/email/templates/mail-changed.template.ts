import { EmailMessage } from '../email-types.ts';
import {
  bodyDivider,
  bodyHighlight,
  bodyParagraph,
  bodyWarmPanel,
  checklistBlock,
  buildTextLines,
  emailSignOff,
  escapeHtml,
  GAME_EMAIL_THEME,
  wrapHtml
} from './layout.ts';

export interface MailChangedTemplateContext {
  name: string;
  oldMail: string;
  newMail: string;
}

export function buildMailChangedEmail(context: MailChangedTemplateContext): EmailMessage {
  const { name, oldMail, newMail } = context;
  const safeName = escapeHtml(name);
  const safeNewMail = escapeHtml(newMail);
  const t = GAME_EMAIL_THEME;
  const subject = 'Aviso de seguridad: tu email en E-VIDENTE fue cambiado';

  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    'Te avisamos que el email asociado a tu cuenta en E-VIDENTE fue actualizado.',
    `Nuevo email: ${newMail}`,
    '',
    'Si fuiste vos, podés ignorar este mensaje.',
    'Si NO reconocés este cambio, contactanos de inmediato.',
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: 'Tu email fue cambiado',
    subtitle: 'Aviso de seguridad de cuenta',
    preheader: `Se actualizó el email de tu cuenta E-VIDENTE a ${newMail}. Si no fuiste vos, revisá esto.`,
    bodyHtml: [
      bodyParagraph(
        `Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>,`
      ),
      bodyParagraph(
        'Te informamos que el email asociado a tu cuenta de <strong>E-VIDENTE</strong> fue actualizado.'
      ),
      bodyHighlight(
        `<span style="font-size: 13px; color: ${t.textMuted}; letter-spacing: 0.04em; text-transform: uppercase; font-weight: 700;">Nuevo email registrado</span><br/>` +
        `<strong style="font-size: 18px; color: ${t.primaryGreen}; line-height: 1.4;">${safeNewMail}</strong>`
      ),
      bodyWarmPanel(
        '¿No fuiste vos?',
        'Si no reconocés este cambio, tu cuenta podría estar en riesgo. Actuá rápido para protegerla.'
      ),
      checklistBlock([
        'Cambiá la contraseña de tu cuenta de juego',
        'Revisá si tenés sesiones abiertas en otros dispositivos',
        'Contactanos si necesitás ayuda para recuperar tu cuenta'
      ]),
      bodyDivider(),
      bodyParagraph(
        `<span style="font-size: 13px; color: ${t.textMuted};">Si fuiste vos, podés ignorar este mensaje.</span>`
      ),
      emailSignOff()
    ].join('')
  });

  return { to: oldMail, toName: name, subject, htmlContent, textContent };
}
