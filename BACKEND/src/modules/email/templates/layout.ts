export const GAME_EMAIL_THEME = {
  // Paleta oficial E-VIDENTE (miPaleta.gd)
  primaryGreen: '#42785e',       // VERDE_BOSQUE — header principal
  primaryGreenDark: '#2d5a45',   // darker shade para gradiente
  goldAccent: '#dbc151',         // ORO_CLARO — acentos dorados
  orangeAccent: '#db9d4b',       // NARANJA_TIERRA — CTA buttons
  blueAccent: '#4b79db',         // AZUL_BRILLANTE — verificación
  grayDark: '#4d525c',           // GRIS_AZULADO — texto títulos
  sageChip: '#c7d6a8',           // sage suave — texto en header
  creamBackground: '#f4f7f2',    // fondo general
  cardBackground: '#ffffff',     // cuerpo del email
  panelTint: '#f0f5f1',          // fondo de highlights
  panelBorder: '#d4e4d9',        // borde de highlights
  textBody: '#3e382a',           // texto principal
  textMuted: '#5c5347',          // texto secundario
  borderSubtle: '#e2e4df',       // bordes generales
  footerBackground: '#eef3ec',   // footer suave
  badgeGold: '#fffbe6',          // fondo de badge dorado
  badgeGoldBorder: '#f0d96a',    // borde del badge
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
  const t = GAME_EMAIL_THEME;
  return `<p style="margin: 0 0 18px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 1.65; color: ${t.textBody};">${text}</p>`;
}

export function bodyHighlight(text: string): string {
  const t = GAME_EMAIL_THEME;
  return `<div style="margin: 0 0 20px; padding: 16px 20px; background: ${t.panelTint}; border: 1.5px solid ${t.panelBorder}; border-left: 4px solid ${t.primaryGreen}; border-radius: 12px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; line-height: 1.55; color: ${t.textBody};">${text}</div>`;
}

export function bodyGoldBadge(text: string): string {
  const t = GAME_EMAIL_THEME;
  return `<div style="margin: 0 0 20px; padding: 18px 24px; background: ${t.badgeGold}; border: 2px solid ${t.badgeGoldBorder}; border-radius: 14px; text-align: center; font-family: 'Rubik', Arial, Helvetica, sans-serif;">${text}</div>`;
}

export function ctaButton(label: string, color: string = GAME_EMAIL_THEME.orangeAccent): string {
  return `<div style="text-align: center; margin: 0 0 24px;">
    <span style="display: inline-block; padding: 14px 36px; background: ${color}; border-radius: 50px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; font-weight: 700; letter-spacing: 0.02em; color: #ffffff; box-shadow: 0 4px 12px rgba(219,157,75,0.35);">${label}</span>
  </div>`;
}

export function ctaLink(label: string, href: string, color: string = GAME_EMAIL_THEME.orangeAccent): string {
  const safeHref = escapeHtml(href);
  const safeLabel = escapeHtml(label);
  return `<div style="text-align: center; margin: 0 0 24px;">
    <a href="${safeHref}" style="display: inline-block; padding: 14px 36px; background: ${color}; border-radius: 50px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; font-weight: 700; letter-spacing: 0.02em; color: #ffffff; text-decoration: none; box-shadow: 0 4px 12px rgba(219,157,75,0.35);">${safeLabel}</a>
  </div>`;
}

export function streakBadge(count: number): string {
  const t = GAME_EMAIL_THEME;
  const label = formatDayLabel(count);
  return `<div style="margin: 0 0 24px; text-align: center;">
    <span style="display: inline-block; padding: 8px 22px; background: ${t.badgeGold}; border: 2px solid ${t.badgeGoldBorder}; border-radius: 50px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 15px; font-weight: 700; color: #5a4300; letter-spacing: 0.04em;">
      🔥 ${count} ${label} de racha
    </span>
  </div>`;
}

interface WrapHtmlOptions {
  headline: string;
  subtitle?: string;
  bodyHtml: string;
  includeNotificationOptOut?: boolean;
  headerEmoji?: string;
  headerScheme?: 'green' | 'blue' | 'gold';
}

export function wrapHtml(options: WrapHtmlOptions): string {
  const t = GAME_EMAIL_THEME;
  const scheme = options.headerScheme ?? 'green';

  const headerGradient: Record<string, string> = {
    green: `linear-gradient(145deg, ${t.primaryGreen} 0%, ${t.primaryGreenDark} 100%)`,
    blue:  `linear-gradient(145deg, ${t.blueAccent} 0%, #2f58bb 100%)`,
    gold:  `linear-gradient(145deg, #b8932c 0%, #8a6b1a 100%)`,
  };

  const emojiBlock = options.headerEmoji
    ? `<div style="font-size: 40px; line-height: 1; margin-bottom: 12px;">${options.headerEmoji}</div>`
    : '';

  const safeHeadline = escapeHtml(options.headline);
  const safeSubtitle = options.subtitle ? escapeHtml(options.subtitle) : '';
  const subtitleBlock = safeSubtitle
    ? `<p style="margin: 8px 0 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 14px; font-weight: 500; letter-spacing: 0.04em; color: ${t.sageChip}; text-transform: uppercase;">${safeSubtitle}</p>`
    : '';

  const optOutHtml = options.includeNotificationOptOut
    ? `<p style="margin: 8px 0 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 12px; line-height: 1.5; color: ${t.textMuted};">Podés desactivar los recordatorios desde tu cuenta en el juego.</p>`
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
  <body style="margin: 0; padding: 0; background-color: ${t.creamBackground}; -webkit-font-smoothing: antialiased;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: ${t.creamBackground};">
      <tr>
        <td align="center" style="padding: 40px 16px 48px;">

          <!-- Card wrapper -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
            style="max-width: 560px; width: 100%; border-collapse: separate; border-spacing: 0;
                   border-radius: 24px; overflow: hidden;
                   box-shadow: 0 8px 40px rgba(40, 50, 40, 0.13);">

            <!-- HEADER -->
            <tr>
              <td style="background: ${headerGradient[scheme]}; padding: 32px 36px 28px; text-align: center;">
                ${emojiBlock}
                <!-- Logo label -->
                <p style="margin: 0 0 10px; font-family: 'Rubik', Arial, Helvetica, sans-serif;
                          font-size: 11px; font-weight: 700; letter-spacing: 0.18em;
                          text-transform: uppercase; color: ${t.sageChip}; opacity: 0.85;">E-VIDENTE</p>
                <h1 style="margin: 0; font-family: 'Rubik', Arial, Helvetica, sans-serif;
                           font-size: 28px; font-weight: 900; line-height: 1.2; color: #ffffff;
                           letter-spacing: -0.01em;">${safeHeadline}</h1>
                ${subtitleBlock}
              </td>
            </tr>

            <!-- Gold accent bar -->
            <tr>
              <td style="background: ${t.goldAccent}; height: 4px; font-size: 0; line-height: 0;">&nbsp;</td>
            </tr>

            <!-- BODY -->
            <tr>
              <td style="background-color: ${t.cardBackground}; padding: 32px 36px 8px;">
                ${options.bodyHtml}
              </td>
            </tr>

            <!-- FOOTER -->
            <tr>
              <td style="background-color: ${t.footerBackground}; padding: 20px 36px 24px;
                         border-top: 1.5px solid ${t.borderSubtle};">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td>
                      <p style="margin: 0; font-family: 'Rubik', Arial, Helvetica, sans-serif;
                                font-size: 12px; line-height: 1.6; color: ${t.textMuted};">
                        <strong style="color: ${t.primaryGreen};">E-VIDENTE</strong> — aprender jugando sobre restricciones alimentarias.
                      </p>
                      ${optOutHtml}
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

          </table>
          <!-- /Card wrapper -->

        </td>
      </tr>
    </table>
  </body>
</html>
  `.trim();
}

export const NOTIFICATION_OPT_OUT_TEXT =
  'Podés desactivar los recordatorios de racha desde tu cuenta en el juego.';
