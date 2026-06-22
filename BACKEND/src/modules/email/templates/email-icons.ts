import { escapeHtml } from './html-utils';
import {
  canUsePublicEmailAssetUrls,
  resolveIconPublicUrl,
  resolveIconSrc,
  type EmailIconVariant
} from './email-assets';

export type EmailIconKey =
  | 'mail'
  | 'welcome'
  | 'streak'
  | 'security'
  | 'shield_check'
  | 'play'
  | 'clock'
  | 'xp'
  | 'check'
  | 'alert';

type EmailIconsBuildMode = 'send' | 'embed';

let iconsBuildMode: EmailIconsBuildMode = 'send';

/** Solo para preview HTML en dev (`/dev/email/preview`). */
export function setEmailIconsBuildMode(mode: EmailIconsBuildMode): void {
  iconsBuildMode = mode;
}

const ICON_TEXT_LABELS: Record<EmailIconKey, string> = {
  mail: 'M',
  welcome: 'E',
  streak: '*',
  security: 'S',
  shield_check: 'OK',
  play: '>',
  clock: 'T',
  xp: 'XP',
  check: '+',
  alert: '!'
};

function iconSrc(icon: EmailIconKey, variant: EmailIconVariant = 'default'): string {
  if (iconsBuildMode === 'embed') {
    return resolveIconSrc(icon, 'embed', variant);
  }
  if (canUsePublicEmailAssetUrls()) {
    return resolveIconPublicUrl(icon, variant);
  }
  return '';
}

function iconTextFallback(
  icon: EmailIconKey,
  size: number,
  display: 'block' | 'inline'
): string {
  const label = escapeHtml(ICON_TEXT_LABELS[icon] ?? '•');
  const fontSize = Math.max(11, size - (label.length > 2 ? 10 : 6));
  const blockStyle =
    display === 'block'
      ? `display:block;margin:0 auto;width:${size}px;height:${size}px;line-height:${size}px;text-align:center;`
      : 'display:inline-block;vertical-align:middle;line-height:1;';
  return `<span style="${blockStyle}font-family:'Rubik',Arial,sans-serif;font-size:${fontSize}px;font-weight:900;color:#42785e;">${label}</span>`;
}

function iconImg(
  icon: EmailIconKey,
  size: number,
  display: 'block' | 'inline',
  variant: EmailIconVariant = 'default'
): string {
  const src = iconSrc(icon, variant);
  if (!src) {
    return iconTextFallback(icon, size, display);
  }
  const safeSrc = escapeHtml(src);
  const displayStyle =
    display === 'block'
      ? 'display:block;margin:0 auto;border:0;'
      : 'display:inline-block;border:0;vertical-align:middle;';
  return `<img src="${safeSrc}" alt="" width="${size}" height="${size}" style="${displayStyle}" />`;
}

export function emailIconImg(icon: EmailIconKey, size = 40): string {
  const img = iconImg(icon, size, 'block');
  if (!img) {
    return '';
  }
  return `<div style="line-height:0;margin:0 auto 12px;">${img}</div>`;
}

export function emailIconInline(icon: EmailIconKey, size = 20): string {
  return iconImg(icon, size, 'inline');
}

export function inlineIconLabel(icon: EmailIconKey, label: string): string {
  const safeLabel = escapeHtml(label);
  const inline = emailIconInline(icon, 18);
  if (!inline) {
    return safeLabel;
  }
  return `<span style="display:inline-block;vertical-align:middle;">${inline}<span style="display:inline-block;vertical-align:middle;margin-left:6px;">${safeLabel}</span></span>`;
}

export function headerIconBadge(icon: EmailIconKey): string {
  const variant: EmailIconVariant = icon === 'streak' ? 'header' : 'default';
  const img = iconImg(icon, 32, 'block', variant);
  if (!img) {
    return '';
  }
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto 16px;">
    <tr>
      <td align="center" width="68" height="68"
        style="width:68px;height:68px;background:rgba(255,255,255,0.12);border:2px solid rgba(232,240,220,0.45);border-radius:34px;line-height:0;">
        ${img}
      </td>
    </tr>
  </table>`;
}

export function featureCardIcon(icon: EmailIconKey): string {
  const size = icon === 'streak' ? 36 : 28;
  const img = iconImg(icon, size, 'block');
  if (!img) {
    return '';
  }
  return `<div style="line-height:0;margin:0 auto 8px;">${img}</div>`;
}
