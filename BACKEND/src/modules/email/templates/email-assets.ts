import fs from 'fs';
import path from 'path';
import { emailConfig } from '../email.config';
import type { EmailIconKey } from './email-icons';

export const EMAIL_LOGO_CID = 'evidente-logo';

export const EMAIL_ICON_KEYS: EmailIconKey[] = [
  'mail',
  'welcome',
  'streak',
  'security',
  'shield_check',
  'play',
  'clock',
  'xp',
  'check',
  'alert'
];

export type EmailIconVariant = 'default' | 'header';

export const EMAIL_ICON_EXTRA_ASSETS: Array<{ file: string; contentId: string }> = [
  { file: 'icons/streak-header.png', contentId: 'ev-icon-streak-header' }
];

export function emailIconCid(icon: EmailIconKey, variant: EmailIconVariant = 'default'): string {
  if (icon === 'streak' && variant === 'header') {
    return 'ev-icon-streak-header';
  }
  return `ev-icon-${icon}`;
}

function iconAssetPath(icon: EmailIconKey, variant: EmailIconVariant = 'default'): string {
  if (icon === 'streak' && variant === 'header') {
    return 'icons/streak-header.png';
  }
  return `icons/${icon}.png`;
}

function assetsRoot(): string {
  const candidates = [
    path.join(__dirname, '..', 'assets'),
    path.join(process.cwd(), 'src', 'modules', 'email', 'assets'),
    path.join(process.cwd(), 'dist', 'modules', 'email', 'assets')
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return path.join(process.cwd(), 'src', 'modules', 'email', 'assets');
}

function readAssetBytes(relPath: string): Buffer | null {
  const fullPath = path.join(assetsRoot(), relPath);
  if (!fs.existsSync(fullPath)) {
    return null;
  }
  try {
    return fs.readFileSync(fullPath);
  } catch {
    return null;
  }
}

const cachedDataUris = new Map<string, string>();

function loadDataUri(relPath: string): string {
  const cached = cachedDataUris.get(relPath);
  if (cached !== undefined) {
    return cached;
  }
  const bytes = readAssetBytes(relPath);
  if (!bytes) {
    cachedDataUris.set(relPath, '');
    return '';
  }
  const dataUri = `data:image/png;base64,${bytes.toString('base64')}`;
  cachedDataUris.set(relPath, dataUri);
  return dataUri;
}

export function loadLogoDataUri(): string {
  const configuredUrl = emailConfig.logoUrl.trim();
  if (configuredUrl.length > 0) {
    return configuredUrl;
  }
  return loadDataUri('logo.png');
}

export function loadIconDataUri(icon: EmailIconKey, variant: EmailIconVariant = 'default'): string {
  return loadDataUri(iconAssetPath(icon, variant));
}

export function resolveLogoSrc(mode: 'cid' | 'embed'): string {
  if (mode === 'cid') {
    return `cid:${EMAIL_LOGO_CID}`;
  }
  return loadLogoDataUri();
}

export function resolveIconSrc(
  icon: EmailIconKey,
  mode: 'cid' | 'embed',
  variant: EmailIconVariant = 'default'
): string {
  if (mode === 'cid') {
    return `cid:${emailIconCid(icon, variant)}`;
  }
  return loadIconDataUri(icon, variant);
}

export interface InlineEmailAttachment {
  name: string;
  contentId: string;
  content: string;
}

export function buildInlineEmailAttachments(html: string): InlineEmailAttachment[] {
  const attachments: InlineEmailAttachment[] = [];

  if (html.includes(`cid:${EMAIL_LOGO_CID}`)) {
    const logoBytes = readAssetBytes('logo.png');
    if (logoBytes) {
      attachments.push({
        name: 'logo.png',
        contentId: EMAIL_LOGO_CID,
        content: logoBytes.toString('base64')
      });
    }
  }

  for (const icon of EMAIL_ICON_KEYS) {
    const cid = emailIconCid(icon);
    if (!html.includes(`cid:${cid}`)) {
      continue;
    }
    const bytes = readAssetBytes(`icons/${icon}.png`);
    if (!bytes) {
      continue;
    }
    attachments.push({
      name: `${icon}.png`,
      contentId: cid,
      content: bytes.toString('base64')
    });
  }

  for (const extra of EMAIL_ICON_EXTRA_ASSETS) {
    if (!html.includes(`cid:${extra.contentId}`)) {
      continue;
    }
    const bytes = readAssetBytes(extra.file);
    if (!bytes) {
      continue;
    }
    attachments.push({
      name: path.basename(extra.file),
      contentId: extra.contentId,
      content: bytes.toString('base64')
    });
  }

  return attachments;
}

export function embedInlineAssetsForPreview(html: string): string {
  let result = html;
  if (result.includes(`cid:${EMAIL_LOGO_CID}`)) {
    const logoSrc = loadLogoDataUri();
    if (logoSrc) {
      result = result.replaceAll(`cid:${EMAIL_LOGO_CID}`, logoSrc);
    }
  }
  for (const icon of EMAIL_ICON_KEYS) {
    const cid = emailIconCid(icon);
    if (!result.includes(`cid:${cid}`)) {
      continue;
    }
    const dataUri = loadIconDataUri(icon);
    if (dataUri) {
      result = result.replaceAll(`cid:${cid}`, dataUri);
    }
  }
  for (const extra of EMAIL_ICON_EXTRA_ASSETS) {
    if (!result.includes(`cid:${extra.contentId}`)) {
      continue;
    }
    const dataUri = loadDataUri(extra.file);
    if (dataUri) {
      result = result.replaceAll(`cid:${extra.contentId}`, dataUri);
    }
  }
  return result;
}
