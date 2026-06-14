export const GAME_EMAIL_THEME = {
  primaryGreen: '#42785e',
  primaryGreenDark: '#3d6b55',
  sageChip: '#c7d6a8',
  creamBackground: '#f4f7f2',
  cardBackground: '#ffffff',
  panelTint: '#e8f0eb',
  textBody: '#3e382a',
  textMuted: '#5c5347',
  textTitle: '#4d525c',
  accentBrown: '#704533',
  borderSubtle: '#e2e4df',
  footerBackground: '#eef3ec'
} as const;

export function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

export function formatDayLabel(count: number): string {
  return count === 1 ? 'día' : 'días';
}

export function buildTextLines(lines: string[]): string {
  return lines.filter((line) => line !== undefined).join('\n');
}

export function bodyParagraph(text: string): string {
  return `<p style="margin: 0 0 16px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 1.6; color: ${GAME_EMAIL_THEME.textBody};">${text}</p>`;
}

export function bodyHighlight(text: string): string {
  return `<p style="margin: 0 0 16px; padding: 14px 16px; background: ${GAME_EMAIL_THEME.panelTint}; border: 1px solid ${GAME_EMAIL_THEME.borderSubtle}; border-radius: 16px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 1.55; color: ${GAME_EMAIL_THEME.textBody};">${text}</p>`;
}

interface WrapHtmlOptions {
  headline: string;
  subtitle?: string;
  bodyHtml: string;
  includeNotificationOptOut?: boolean;
}

export function wrapHtml(options: WrapHtmlOptions): string {
  const theme = GAME_EMAIL_THEME;
  const safeHeadline = escapeHtml(options.headline);
  const safeSubtitle = options.subtitle ? escapeHtml(options.subtitle) : '';
  const subtitleBlock = safeSubtitle
    ? `<p style="margin: 8px 0 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 15px; line-height: 1.4; color: ${theme.sageChip};">${safeSubtitle}</p>`
    : '';

  const optOutHtml = options.includeNotificationOptOut
    ? bodyParagraph(
        `<span style="font-size: 13px; color: ${theme.textMuted};">Podés desactivar los recordatorios de racha desde tu cuenta en el juego.</span>`
      )
    : '';

  return `
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${safeHeadline} · E-VIDENTE</title>
    <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@400;500;700;900&display=swap" rel="stylesheet" />
  </head>
  <body style="margin: 0; padding: 0; background-color: ${theme.creamBackground};">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: ${theme.creamBackground};">
      <tr>
        <td align="center" style="padding: 32px 16px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width: 560px; width: 100%; border-collapse: separate; border-spacing: 0; border: 1px solid ${theme.borderSubtle}; border-radius: 28px; overflow: hidden; box-shadow: 0 12px 32px rgba(40, 40, 46, 0.08);">
            <tr>
              <td style="background: linear-gradient(135deg, ${theme.primaryGreen} 0%, ${theme.primaryGreenDark} 100%); padding: 28px 32px 24px;">
                <p style="margin: 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 13px; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: ${theme.sageChip};">E-VIDENTE</p>
                <h1 style="margin: 10px 0 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 30px; font-weight: 900; line-height: 1.15; color: #ffffff;">${safeHeadline}</h1>
                ${subtitleBlock}
              </td>
            </tr>
            <tr>
              <td style="background-color: ${theme.cardBackground}; padding: 28px 32px 12px;">
                ${options.bodyHtml}
                ${optOutHtml}
              </td>
            </tr>
            <tr>
              <td style="background-color: ${theme.footerBackground}; padding: 18px 32px 24px; border-top: 1px solid ${theme.borderSubtle};">
                <p style="margin: 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 12px; line-height: 1.5; color: ${theme.textMuted};">
                  E-VIDENTE — aprender jugando sobre restricciones alimentarias.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
  `.trim();
}

export const NOTIFICATION_OPT_OUT_TEXT =
  'Podés desactivar los recordatorios de racha desde tu cuenta en el juego.';
