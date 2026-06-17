import { EmailMessage } from '../email.types';
import {
  bodyGoldBadge,
  bodyParagraph,
  buildTextLines,
  escapeHtml,
  GAME_EMAIL_THEME,
  wrapHtml
} from './layout';

export interface EmailVerificationTemplateContext {
  name: string;
  mail: string;
  code: string;
  expiresMinutes: number;
}

export function buildEmailVerificationEmail(
  context: EmailVerificationTemplateContext
): EmailMessage {
  const { name, mail, code, expiresMinutes } = context;
  const safeName = escapeHtml(name);
  const safeCode = escapeHtml(code);
  const t = GAME_EMAIL_THEME;

  // Formatea el código como "XXX XXX" para mejor legibilidad
  const formattedCode = safeCode.length === 6
    ? `${safeCode.slice(0, 3)} ${safeCode.slice(3)}`
    : safeCode;

  const subject = `${code} es tu código de verificación E-VIDENTE`;

  const textContent = buildTextLines([
    `Hola ${name},`,
    '',
    `Tu código de verificación es: ${code}`,
    `Válido por ${expiresMinutes} minutos.`,
    '',
    'Ingresá este código en el juego para confirmar tu email.',
    'Si no lo pediste vos, ignorá este mensaje.',
    '',
    '— Equipo E-VIDENTE'
  ]);

  const htmlContent = wrapHtml({
    headline: 'Verificá tu email',
    subtitle: `Código válido por ${expiresMinutes} minutos`,
    headerEmoji: '🔐',
    headerScheme: 'blue',
    bodyHtml: [
      bodyParagraph(
        `Hola <strong style="color: ${t.primaryGreen};">${safeName}</strong>,`
      ),
      bodyParagraph('Ingresá este código en el juego para confirmar tu email:'),
      // Badge dorado con el código grande y llamativo
      bodyGoldBadge(
        `<p style="margin: 0 0 4px; font-family: 'Rubik', Arial, sans-serif; font-size: 12px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: #7a6200;">Código de verificación</p>` +
        `<p style="margin: 0; font-family: 'Rubik', 'Courier New', monospace; font-size: 44px; font-weight: 900; letter-spacing: 0.18em; color: #4a3800; line-height: 1.1;">${formattedCode}</p>`
      ),
      bodyParagraph(
        `<span style="font-size: 13px; color: ${t.textMuted};">⏱ Expira en <strong>${expiresMinutes} minutos</strong>. Si no fuiste vos, podés ignorar este mensaje.</span>`
      )
    ].join('')
  });

  return { to: mail, toName: name, subject, htmlContent, textContent };
}
