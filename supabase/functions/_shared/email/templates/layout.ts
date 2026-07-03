import {
  EmailIconKey,
  featureCardIcon,
  headerIconBadge,
  emailIconInline
} from './email-icons.ts';
import { emailLogoBlock } from './email-logo.ts';
import { escapeHtml } from './html-utils.ts';

export const GAME_EMAIL_THEME = {
  primaryGreen: '#42785e',
  primaryGreenLight: '#4a8a6a',
  primaryGreenDark: '#2d5a45',
  goldAccent: '#dbc151',
  goldDark: '#b8932c',
  grayDark: '#4d525c',
  sageChip: '#c7d6a8',
  creamBackground: '#f4f7f2',
  cardBackground: '#ffffff',
  panelTint: '#f0f5f1',
  panelBorder: '#d4e4d9',
  panelWarm: '#faf6e8',
  panelWarmBorder: '#e8d9a0',
  textBody: '#3e382a',
  textMuted: '#5c5347',
  borderSubtle: '#e2e4df',
  footerBackground: '#eef3ec',
  badgeGold: '#fffbe6',
  badgeGoldBorder: '#f0d96a',
  badgeMuted: '#f3f5f2',
  badgeMutedBorder: '#c8d4cb'
} as const;

export { escapeHtml } from './html-utils.ts';

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

export function bodyWarmPanel(title: string, text: string): string {
  const t = GAME_EMAIL_THEME;
  const safeTitle = escapeHtml(title);
  return `<div style="margin: 0 0 20px; padding: 18px 20px; background: ${t.panelWarm}; border: 1.5px solid ${t.panelWarmBorder}; border-radius: 14px; font-family: 'Rubik', Arial, Helvetica, sans-serif;">
    <p style="margin: 0 0 8px; font-size: 12px; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: ${t.goldDark};">${safeTitle}</p>
    <p style="margin: 0; font-size: 15px; line-height: 1.55; color: ${t.textBody};">${text}</p>
  </div>`;
}

export function bodyDivider(): string {
  const t = GAME_EMAIL_THEME;
  return `<div style="margin: 4px 0 22px; height: 1px; background: linear-gradient(90deg, transparent, ${t.borderSubtle}, transparent);">&nbsp;</div>`;
}

export function emailSignOff(): string {
  const t = GAME_EMAIL_THEME;
  return `<p style="margin: 0 0 8px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 15px; line-height: 1.5; color: ${t.textMuted};">
    Con cariño,<br/>
    <strong style="color: ${t.primaryGreen};">Equipo E-VIDENTE</strong>
  </p>`;
}

interface FeatureCardItem {
  icon: EmailIconKey;
  title: string;
  text: string;
}

export function featureCardRow(items: FeatureCardItem[]): string {
  const t = GAME_EMAIL_THEME;
  const cells = items
    .map((item) => {
      const safeTitle = escapeHtml(item.title);
      const safeText = escapeHtml(item.text);
      return `<td width="33%" style="width: 33%; padding: 6px; vertical-align: top;">
        <div style="background: ${t.panelTint}; border: 1.5px solid ${t.panelBorder}; border-radius: 14px; padding: 16px 12px; text-align: center;">
          ${featureCardIcon(item.icon)}
          <p style="margin: 0 0 4px; font-family: 'Rubik', Arial, sans-serif; font-size: 13px; font-weight: 700; color: ${t.primaryGreen};">${safeTitle}</p>
          <p style="margin: 0; font-family: 'Rubik', Arial, sans-serif; font-size: 12px; line-height: 1.45; color: ${t.textMuted};">${safeText}</p>
        </div>
      </td>`;
    })
    .join('');

  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 0 0 24px;">
    <tr>${cells}</tr>
  </table>`;
}

export function numberedSteps(steps: string[]): string {
  const t = GAME_EMAIL_THEME;
  const rows = steps
    .map((step, index) => {
      const stepNumber = index + 1;
      const safeStep = escapeHtml(step);
      return `<tr>
        <td width="36" style="width: 36px; padding: 0 12px 14px 0; vertical-align: top;">
          <div style="width: 28px; height: 28px; background: ${t.primaryGreen}; border-radius: 14px; text-align: center; line-height: 28px; font-family: 'Rubik', Arial, sans-serif; font-size: 13px; font-weight: 700; color: #ffffff;">${stepNumber}</div>
        </td>
        <td style="padding: 0 0 14px; vertical-align: top; font-family: 'Rubik', Arial, sans-serif; font-size: 15px; line-height: 1.5; color: ${t.textBody};">${safeStep}</td>
      </tr>`;
    })
    .join('');

  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 0 0 20px;">${rows}</table>`;
}

export function checklistBlock(items: string[]): string {
  const t = GAME_EMAIL_THEME;
  const rows = items
    .map((item) => {
      const icon = emailIconInline('check', 18);
      const safeItem = escapeHtml(item);
      return `<tr>
        <td width="28" style="width: 28px; padding: 0 10px 10px 0; vertical-align: top; line-height: 0;">${icon}</td>
        <td style="padding: 0 0 10px; vertical-align: top; font-family: 'Rubik', Arial, sans-serif; font-size: 14px; line-height: 1.5; color: ${t.textBody};">${safeItem}</td>
      </tr>`;
    })
    .join('');

  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 0 0 16px;">${rows}</table>`;
}

/** Bloque OTP con cajas por dígito (copiable seguido, sin espacios). */
export function verificationCodeBlock(code: string): string {
  const t = GAME_EMAIL_THEME;
  const digits = code.replace(/\D/g, '').slice(0, 6).split('');
  const digitBoxes = digits
    .map((digit) => {
      const safeDigit = escapeHtml(digit);
      return `<td style="padding: 0 3px;">
        <div style="width: 42px; height: 52px; background: #ffffff; border: 2px solid ${t.badgeGoldBorder}; border-radius: 10px; text-align: center; line-height: 52px; font-family: 'Rubik', 'Courier New', monospace; font-size: 26px; font-weight: 900; color: #4a3800;">${safeDigit}</div>
      </td>`;
    })
    .join('');

  return `<div style="margin: 0 0 20px; padding: 22px 20px; background: ${t.badgeGold}; border: 2px solid ${t.badgeGoldBorder}; border-radius: 16px; text-align: center; font-family: 'Rubik', Arial, sans-serif;">
    <p style="margin: 0 0 14px; font-size: 11px; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: #7a6200;">Tu código de verificación</p>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin: 0 auto 14px;">
      <tr>${digitBoxes}</tr>
    </table>
    <p style="margin: 0; font-size: 12px; line-height: 1.5; color: ${t.textMuted};">Son 6 números, sin espacios. También están en el asunto del mail para copiarlos rápido.</p>
  </div>`;
}

export function verificationCopyHint(): string {
  const t = GAME_EMAIL_THEME;
  return `<p style="margin: -4px 0 20px; text-align: center; font-size: 13px; line-height: 1.55; color: ${t.textMuted};">En la PC: seleccioná el código de arriba o del <strong>asunto</strong>, copialo y pegalo en el juego. No hace falta abrir ningún enlace.</p>`;
}

export function ctaButton(label: string, color: string = GAME_EMAIL_THEME.primaryGreen): string {
  const safeLabel = escapeHtml(label);
  return `<div style="text-align: center; margin: 0 0 24px;">
    <span style="display: inline-block; padding: 15px 40px; background: ${color}; border: 2px solid ${GAME_EMAIL_THEME.goldAccent}; border-radius: 50px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; font-weight: 700; letter-spacing: 0.02em; color: #ffffff; box-shadow: 0 6px 18px rgba(66,120,94,0.28);">${safeLabel}</span>
  </div>`;
}

export function ctaLink(label: string, href: string, color: string = GAME_EMAIL_THEME.primaryGreen): string {
  const safeHref = escapeHtml(href);
  const safeLabel = escapeHtml(label);
  return `<div style="text-align: center; margin: 0 0 24px;">
    <a href="${safeHref}" style="display: inline-block; padding: 15px 40px; background: ${color}; border: 2px solid ${GAME_EMAIL_THEME.goldAccent}; border-radius: 50px; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 16px; font-weight: 700; letter-spacing: 0.02em; color: #ffffff; text-decoration: none; box-shadow: 0 6px 18px rgba(66,120,94,0.28);">${safeLabel}</a>
  </div>`;
}

/** Botones principales de mails de racha: jugar + ver ranking (si hay URLs configuradas). */
export function buildStreakEmailCtas(playUrl?: string, leaderboardUrl?: string): string {
  const boton_jugar = playUrl
    ? ctaLink('Jugar ahora', playUrl)
    : ctaButton('Jugar ahora');

  const boton_ranking = leaderboardUrl
    ? ctaLink('Ver tu puesto en el ranking', leaderboardUrl, GAME_EMAIL_THEME.goldDark)
    : '';

  return [boton_jugar, boton_ranking].filter((bloque) => bloque.length > 0).join('');
}

/** CTAs del mail de bienvenida: jugar + ver ranking global. */
export function buildWelcomeEmailCtas(playUrl?: string, leaderboardUrl?: string): string {
  const boton_jugar = playUrl
    ? ctaLink('Empezar a jugar', playUrl)
    : ctaButton('Empezar a jugar');

  const boton_ranking = leaderboardUrl
    ? ctaLink('Ver el ranking global', leaderboardUrl, GAME_EMAIL_THEME.goldDark)
    : '';

  return [boton_jugar, boton_ranking].filter((bloque) => bloque.length > 0).join('');
}

export function streakHero(count: number, variant: 'active' | 'at_risk' | 'last_chance' | 'lost'): string {
  const t = GAME_EMAIL_THEME;
  const label = formatDayLabel(count);
  const icon = emailIconInline('streak', 24);

  const styles: Record<string, { bg: string; border: string; numberColor: string; label: string }> = {
    active: {
      bg: t.badgeGold,
      border: t.badgeGoldBorder,
      numberColor: '#5a4300',
      label: 'Racha activa'
    },
    at_risk: {
      bg: t.panelWarm,
      border: t.panelWarmBorder,
      numberColor: '#6b4f00',
      label: 'Racha en riesgo'
    },
    last_chance: {
      bg: t.panelWarm,
      border: t.panelWarmBorder,
      numberColor: '#6b4f00',
      label: 'Última hora'
    },
    lost: {
      bg: t.badgeMuted,
      border: t.badgeMutedBorder,
      numberColor: t.grayDark,
      label: 'Racha reiniciada'
    }
  };

  const style = styles[variant];
  const displayCount = variant === 'lost' ? '0' : String(count);
  const sublabel =
    variant === 'lost'
      ? `Antes llevabas ${count} ${label}`
      : `${count} ${label} consecutivos`;

  return `<div style="margin: 0 0 24px; padding: 20px 24px; background: ${style.bg}; border: 2px solid ${style.border}; border-radius: 16px; text-align: center; font-family: 'Rubik', Arial, sans-serif;">
    <p style="margin: 0 0 10px; font-size: 11px; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: ${style.numberColor};">${escapeHtml(style.label)}</p>
    <div style="margin: 0 0 6px; line-height: 1;">${icon}<span style="display:inline-block;vertical-align:middle;font-size:48px;font-weight:900;color:${style.numberColor};line-height:1;margin-left:4px;">${displayCount}</span></div>
    <p style="margin: 0; font-size: 14px; color: ${t.textMuted};">${escapeHtml(sublabel)}</p>
  </div>`;
}

interface WrapHtmlOptions {
  headline: string;
  subtitle?: string;
  preheader?: string;
  bodyHtml: string;
  includeNotificationOptOut?: boolean;
  headerIcon?: EmailIconKey;
}

export function wrapHtml(options: WrapHtmlOptions): string {
  const t = GAME_EMAIL_THEME;
  const headerGradient = `linear-gradient(155deg, ${t.primaryGreenLight} 0%, ${t.primaryGreen} 45%, ${t.primaryGreenDark} 100%)`;

  const iconBlock = options.headerIcon ? headerIconBadge(options.headerIcon) : '';

  const safeHeadline = escapeHtml(options.headline);
  const safeSubtitle = options.subtitle ? escapeHtml(options.subtitle) : '';
  const subtitleBlock = safeSubtitle
    ? `<p style="margin: 10px 0 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 13px; font-weight: 500; letter-spacing: 0.06em; color: ${t.sageChip}; text-transform: uppercase; opacity: 0.95;">${safeSubtitle}</p>`
    : '';

  const preheaderBlock = options.preheader
    ? `<div style="display: none; max-height: 0; overflow: hidden; mso-hide: all; font-size: 1px; line-height: 1px; color: ${t.creamBackground};">${escapeHtml(options.preheader)}</div>`
    : '';

  const optOutHtml = options.includeNotificationOptOut
    ? `<p style="margin: 10px 0 0; font-family: 'Rubik', Arial, Helvetica, sans-serif; font-size: 12px; line-height: 1.5; color: ${t.textMuted};">Podés desactivar los recordatorios desde tu cuenta en el juego.</p>`
    : '';

  return `
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light" />
    <meta name="supported-color-schemes" content="light" />
    <title>${safeHeadline} · E-VIDENTE</title>
    <link href="https://fonts.googleapis.com/css2?family=Rubik:wght@400;500;700;900&display=swap" rel="stylesheet" />
  </head>
  <body style="margin: 0; padding: 0; background-color: ${t.creamBackground}; -webkit-font-smoothing: antialiased;">
    ${preheaderBlock}
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: ${t.creamBackground};">
      <tr>
        <td align="center" style="padding: 36px 16px 48px;">

          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
            style="max-width: 560px; width: 100%; border-collapse: separate; border-spacing: 0;
                   border-radius: 24px; overflow: hidden;
                   box-shadow: 0 10px 44px rgba(40, 50, 40, 0.14); border: 1px solid ${t.borderSubtle};">

            <tr>
              <td style="background: ${headerGradient}; padding: 28px 36px 26px; text-align: center;">
                ${emailLogoBlock(72)}
                ${iconBlock}
                <h1 style="margin: 0; font-family: 'Rubik', Arial, Helvetica, sans-serif;
                           font-size: 26px; font-weight: 900; line-height: 1.25; color: #ffffff;
                           letter-spacing: -0.02em;">${safeHeadline}</h1>
                ${subtitleBlock}
              </td>
            </tr>

            <tr>
              <td style="background: ${t.goldAccent}; height: 5px; font-size: 0; line-height: 0;">&nbsp;</td>
            </tr>

            <tr>
              <td style="background-color: ${t.cardBackground}; padding: 32px 36px 12px;">
                ${options.bodyHtml}
              </td>
            </tr>

            <tr>
              <td style="background-color: ${t.footerBackground}; padding: 22px 36px 26px;
                         border-top: 1.5px solid ${t.borderSubtle};">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td style="padding-bottom: 12px;">
                      <div style="height: 3px; width: 48px; background: ${t.goldAccent}; border-radius: 2px; margin-bottom: 14px;">&nbsp;</div>
                      <p style="margin: 0; font-family: 'Rubik', Arial, Helvetica, sans-serif;
                                font-size: 12px; line-height: 1.65; color: ${t.textMuted};">
                        <strong style="color: ${t.primaryGreen}; font-size: 13px;">E-VIDENTE</strong><br/>
                        Aprender jugando sobre restricciones alimentarias.
                      </p>
                      ${optOutHtml}
                    </td>
                  </tr>
                </table>
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
