import { EmailMessage } from '../email.types';
import { inlineIconLabel } from './email-icons';
import {
  bodyDivider,
  bodyParagraph,
  buildTextLines,
  emailSignOff,
  escapeHtml,
  GAME_EMAIL_THEME,
  numberedSteps,
  verificationCodeBlock,
  verificationCopyHint,
  wrapHtml
} from './layout';

export interface EmailVerificationTemplateContext {
  name: string;
  mail: string;
  code: string;
  expiresMinutes: number;
  expiresAt?: Date;
}

export function buildEmailVerificationEmail(
  context: EmailVerificationTemplateContext
): EmailMessage {
  const { name, mail, code, expiresMinutes } = context;
  const digitsOnly = code.replace(/\D/g, '').slice(0, 6);
  const safeName = escapeHtml(name);
  const t = GAME_EMAIL_THEME;

  const subject = `Código E-VIDENTE: ${digitsOnly} (verificá tu mail)`;

  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    `Tu código de verificación es: ${digitsOnly}`,
    '(6 números seguidos, sin espacios)',
    `Válido por ${expiresMinutes} minutos.`,
    '',
    'Copiá el código del asunto o de este mail y pegalo en el juego.',
    '',
    '1. Abrí E-VIDENTE',
    '2. Pegá el código en la pantalla de verificación',
    '3. Listo — tu cuenta quedará confirmada',
    '',
    'Si no lo pediste vos, ignorá este mensaje.',
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: 'Verificá tu email',
    subtitle: `Código válido por ${expiresMinutes} minutos`,
    preheader: `Tu código es ${digitsOnly}. Copialo del mail o del asunto y pegalo en el juego.`,
    bodyHtml: [
      bodyParagraph(
        `Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>,`
      ),
      bodyParagraph(
        'Usá este código para confirmar tu mail en E-VIDENTE. Es distinto del mail de bienvenida.'
      ),
      verificationCodeBlock(digitsOnly),
      verificationCopyHint(),
      bodyParagraph(
        `<span style="font-size: 13px; color: ${t.textMuted};">${inlineIconLabel('clock', `Expira en ${expiresMinutes} minutos`)}</span>`
      ),
      bodyDivider(),
      numberedSteps([
        'Abrí E-VIDENTE en tu dispositivo',
        'Copiá el código (del bloque de arriba o del asunto del mail)',
        'Pegalo en la pantalla de verificación del juego'
      ]),
      bodyParagraph(
        `<span style="font-size: 13px; color: ${t.textMuted};">Si no pediste este código, ignorá el mensaje. Nadie puede verificar tu cuenta sin acceso a tu mail.</span>`
      ),
      emailSignOff()
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
