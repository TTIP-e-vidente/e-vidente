import crypto from 'crypto';
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
    path.join(process.cwd(), 'dist', 'modules', 'email', 'assets'),
    path.join(process.cwd(), 'src', 'modules', 'email', 'assets')
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return path.join(process.cwd(), 'src', 'modules', 'email', 'assets');
}

export function resolveEmailAssetsDirectory(): string {
  return assetsRoot();
}

function isLocalAssetHost(url: string): boolean {
  return /localhost|127\.0\.0\.1/i.test(url);
}

export function canUsePublicEmailAssetUrls(): boolean {
  const base = emailConfig.assetsBaseUrl.trim();
  return base.length > 0 && !isLocalAssetHost(base);
}

export function resolveIconPublicUrl(
  icon: EmailIconKey,
  variant: EmailIconVariant = 'default'
): string {
  const base = emailConfig.assetsBaseUrl.trim().replace(/\/+$/, '');
  if (!base || isLocalAssetHost(base)) {
    return '';
  }
  const rel = iconAssetPath(icon, variant).replace(/\\/g, '/');
  return withCacheBustVersion(`${base}/${rel}`, rel);
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

const cachedVersions = new Map<string, string>();

/**
 * Hash corto del contenido del asset, para invalidar el cache de imágenes de
 * los clientes de mail (Gmail entre otros cachea agresivamente por URL: sin
 * esto, actualizar logo.png/íconos no se refleja para destinatarios que ya
 * recibieron un mail con la misma URL).
 */
function assetVersion(relPath: string): string {
  const cached = cachedVersions.get(relPath);
  if (cached !== undefined) {
    return cached;
  }
  const bytes = readAssetBytes(relPath);
  const version = bytes ? crypto.createHash('sha256').update(bytes).digest('hex').slice(0, 8) : '';
  cachedVersions.set(relPath, version);
  return version;
}

function withCacheBustVersion(url: string, relPath: string): string {
  const version = assetVersion(relPath);
  if (!version) {
    return url;
  }
  const separator = url.includes('?') ? '&' : '?';
  return `${url}${separator}v=${version}`;
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

/**
 * A diferencia de los íconos (que degradan a texto si no hay CDN configurado),
 * el logo es un único asset chico y crítico para la marca, así que 'embed' hace
 * el fallback completo acá mismo: URL explícita > CDN configurado > base64 local.
 * CID no se usa para envíos reales (Brevo no lo renderiza inline, ver
 * buildInlineEmailAttachments); solo queda como opción explícita.
 */
export function resolveLogoSrc(mode: 'cid' | 'embed'): string {
  if (mode === 'cid') {
    return `cid:${EMAIL_LOGO_CID}`;
  }
  const configuredUrl = emailConfig.logoUrl.trim();
  if (configuredUrl.length > 0) {
    return withCacheBustVersion(configuredUrl, 'logo.png');
  }
  if (canUsePublicEmailAssetUrls()) {
    const base = emailConfig.assetsBaseUrl.trim().replace(/\/+$/, '');
    return withCacheBustVersion(`${base}/logo.png`, 'logo.png');
  }
  return loadDataUri('logo.png');
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
  // Brevo transactional API no renderiza CID inline; evitamos adjuntos huérfanos.
  void html;
  return [];
}

export function embedInlineAssetsForPreview(html: string): string {
  let result = html;

  if (canUsePublicEmailAssetUrls()) {
    for (const icon of EMAIL_ICON_KEYS) {
      const publicUrl = resolveIconPublicUrl(icon);
      if (publicUrl && result.includes(publicUrl)) {
        const dataUri = loadIconDataUri(icon);
        if (dataUri) {
          result = result.replaceAll(publicUrl, dataUri);
        }
      }
      const headerUrl = resolveIconPublicUrl(icon, 'header');
      if (headerUrl && result.includes(headerUrl)) {
        const dataUri = loadIconDataUri(icon, 'header');
        if (dataUri) {
          result = result.replaceAll(headerUrl, dataUri);
        }
      }
    }
    for (const extra of EMAIL_ICON_EXTRA_ASSETS) {
      const base = emailConfig.assetsBaseUrl.trim().replace(/\/+$/, '');
      const publicUrl = `${base}/${extra.file.replace(/\\/g, '/')}`;
      if (result.includes(publicUrl)) {
        const dataUri = loadDataUri(extra.file);
        if (dataUri) {
          result = result.replaceAll(publicUrl, dataUri);
        }
      }
    }
  }

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
