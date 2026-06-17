import { EmailMessage } from '../email.types';
import {
  bodyHighlight,
  bodyParagraph,
  buildTextLines,
  escapeHtml,
  GAME_EMAIL_THEME,
  wrapHtml
} from './layout';

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
    headerEmoji: '🔒',
    headerScheme: 'gold',
    bodyHtml: [
      bodyParagraph(
        `Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>,`
      ),
      bodyParagraph(
        'Te informamos que el email asociado a tu cuenta de <strong>E-VIDENTE</strong> fue actualizado.'
      ),
      bodyHighlight(
        `<span style="font-size: 14px; color: ${t.textMuted};">Nuevo email registrado:</span><br/>` +
        `<strong style="font-size: 17px; color: ${t.primaryGreen};">${safeNewMail}</strong>`
      ),
      bodyParagraph(
        `<span style="font-size: 13px; color: ${t.textMuted};">` +
        `Si fuiste vos, podés ignorar este mensaje. ` +
        `Si <strong>no reconocés este cambio</strong>, contactanos de inmediato para proteger tu cuenta.` +
        `</span>`
      )
    ].join('')
  });

  return { to: oldMail, toName: name, subject, htmlContent, textContent };
}
