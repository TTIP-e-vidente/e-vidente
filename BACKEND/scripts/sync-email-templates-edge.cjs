/**
 * Copia los templates HTML del backend Express a Supabase Edge Functions.
 * Fuente de verdad: BACKEND/src/modules/email/templates/
 *
 * Uso: node scripts/sync-email-templates-edge.cjs
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const BACKEND_ROOT = path.join(__dirname, '..');
const REPO_ROOT = path.join(BACKEND_ROOT, '..');
const SRC_TEMPLATES = path.join(BACKEND_ROOT, 'src', 'modules', 'email', 'templates');
const SRC_ASSETS = path.join(BACKEND_ROOT, 'src', 'modules', 'email', 'assets');
const DEST_ROOT = path.join(REPO_ROOT, 'supabase', 'functions', '_shared', 'email');
const DEST_TEMPLATES = path.join(DEST_ROOT, 'templates');

const COPY_FILES = [
  'html-utils.ts',
  'layout.ts',
  'email-icons.ts',
  'email-logo.ts',
  'email-verification.template.ts',
  'welcome.template.ts',
  'account-verified.template.ts',
  'streak-at-risk.template.ts',
  'streak-last-chance.template.ts',
  'streak-lost.template.ts',
  'mail-changed.template.ts',
];

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function writeTemplateTypes() {
  const content = `/** Generado por sync-email-templates-edge.cjs */
export interface WelcomeTemplateContext {
  name: string;
  mail: string;
  playUrl?: string;
  leaderboardUrl?: string;
}

export interface AccountVerifiedTemplateContext {
  name: string;
  mail: string;
  playUrl?: string;
  leaderboardUrl?: string;
}

export interface StreakTemplateContext {
  name: string;
  mail: string;
  streakCount: number;
  playUrl?: string;
  leaderboardUrl?: string;
}
`;
  fs.writeFileSync(path.join(DEST_TEMPLATES, 'types.ts'), content, 'utf8');
}

function patchTemplateImports(content) {
  return content
    .replaceAll("from '../email.types'", "from '../email-types.ts'")
    .replaceAll("from './email-assets'", "from '../email-assets.ts'")
    .replaceAll("from './html-utils'", "from './html-utils.ts'")
    .replaceAll("from './email-icons'", "from './email-icons.ts'")
    .replaceAll("from './layout'", "from './layout.ts'")
    .replaceAll("from './email-logo'", "from './email-logo.ts'")
    .replaceAll("from './types'", "from './types.ts'")
    .replaceAll("from '../../leaderboard/leaderboard.types'", '');
}

function writeAppDeepLinks() {
  const content = `/** Generado por sync-email-templates-edge.cjs — no editar a mano. */
export function buildAppDeepLink(baseUrl: string, params: Record<string, string>): string {
  const trimmedBase = baseUrl.trim();
  if (!trimmedBase) return '';

  const query = new URLSearchParams(params).toString();
  if (!query) return trimmedBase;

  const separator = trimmedBase.includes('?') ? '&' : '?';
  return \`\${trimmedBase}\${separator}\${query}\`;
}

export function buildLeaderboardDeepLink(
  baseUrl: string,
  scope = 'global_xp',
): string {
  return buildAppDeepLink(baseUrl, {
    open: 'leaderboard',
    scope,
  });
}
`;
  fs.writeFileSync(path.join(DEST_TEMPLATES, 'app-deep-links.ts'), content, 'utf8');
}

function toDataUri(filePath) {
  if (!fs.existsSync(filePath)) {
    return '';
  }
  const bytes = fs.readFileSync(filePath);
  return `data:image/png;base64,${bytes.toString('base64')}`;
}

function toVersion(filePath) {
  if (!fs.existsSync(filePath)) {
    return '';
  }
  const bytes = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(bytes).digest('hex').slice(0, 8);
}

function writeEmailAssets() {
  const iconKeys = [
    'mail',
    'welcome',
    'streak',
    'security',
    'shield_check',
    'play',
    'clock',
    'xp',
    'check',
    'alert',
  ];

  const relPaths = ['logo.png', 'icons/streak-header.png', ...iconKeys.map((icon) => `icons/${icon}.png`)];

  const embedded = {};
  const versions = {};
  for (const rel of relPaths) {
    const filePath = rel === 'logo.png' ? path.join(SRC_ASSETS, 'logo.png') : path.join(SRC_ASSETS, ...rel.split('/'));
    embedded[rel] = toDataUri(filePath);
    versions[rel] = toVersion(filePath);
  }

  const content = `/** Generado por sync-email-templates-edge.cjs — assets embebidos para Brevo/Edge. */
import type { EmailIconKey } from './templates/email-icons.ts';

export type EmailIconVariant = 'default' | 'header';

const EMBEDDED_ASSETS: Record<string, string> = ${JSON.stringify(embedded, null, 2)};

// Hash corto del contenido de cada asset: se agrega como ?v= a las URLs
// públicas para invalidar el cache de imágenes de los clientes de mail
// (Gmail entre otros cachea agresivamente por URL — sin esto, actualizar
// logo.png/íconos no se refleja para destinatarios que ya recibieron un
// mail con la misma URL).
const ASSET_VERSIONS: Record<string, string> = ${JSON.stringify(versions, null, 2)};

function withCacheBustVersion(url: string, rel: string): string {
  const version = ASSET_VERSIONS[rel];
  if (!version) {
    return url;
  }
  const separator = url.includes('?') ? '&' : '?';
  return \`\${url}\${separator}v=\${version}\`;
}

function iconAssetPath(icon: EmailIconKey, variant: EmailIconVariant = 'default'): string {
  if (icon === 'streak' && variant === 'header') {
    return 'icons/streak-header.png';
  }
  return \`icons/\${icon}.png\`;
}

function externalAssetsBase(): string {
  const explicit = (Deno.env.get('EMAIL_ASSETS_BASE_URL') ?? '').trim().replace(/\\/+$/, '');
  if (explicit.length > 0 && !/localhost|127\\.0\\.0\\.1/i.test(explicit)) {
    return explicit;
  }
  return '';
}

export function canUsePublicEmailAssetUrls(): boolean {
  return externalAssetsBase().length > 0 || Object.values(EMBEDDED_ASSETS).some((v) => v.length > 0);
}

export function resolveIconPublicUrl(
  icon: EmailIconKey,
  variant: EmailIconVariant = 'default',
): string {
  const external = externalAssetsBase();
  const rel = iconAssetPath(icon, variant);
  if (external.length > 0) {
    return withCacheBustVersion(\`\${external}/\${rel}\`, rel);
  }
  return EMBEDDED_ASSETS[rel] ?? '';
}

export function resolveLogoSrc(_mode: 'cid' | 'embed'): string {
  const logoUrl = (Deno.env.get('EMAIL_LOGO_URL') ?? '').trim();
  if (logoUrl.length > 0) {
    return withCacheBustVersion(logoUrl, 'logo.png');
  }
  const external = externalAssetsBase();
  if (external.length > 0) {
    return withCacheBustVersion(\`\${external}/logo.png\`, 'logo.png');
  }
  return EMBEDDED_ASSETS['logo.png'] ?? '';
}

export function resolveIconSrc(
  icon: EmailIconKey,
  _mode: 'cid' | 'embed',
  variant: EmailIconVariant = 'default',
): string {
  return resolveIconPublicUrl(icon, variant);
}
`;
  fs.writeFileSync(path.join(DEST_ROOT, 'email-assets.ts'), content, 'utf8');
}

function main() {
  ensureDir(DEST_TEMPLATES);

  for (const file of COPY_FILES) {
    const src = path.join(SRC_TEMPLATES, file);
    if (!fs.existsSync(src)) {
      console.warn('[sync:email-edge] skip missing', file);
      continue;
    }
    const raw = fs.readFileSync(src, 'utf8');
    fs.writeFileSync(path.join(DEST_TEMPLATES, file), patchTemplateImports(raw), 'utf8');
    console.log('[sync:email-edge] copied', file);
  }

  writeAppDeepLinks();
  writeTemplateTypes();
  writeEmailAssets();
  console.log('[sync:email-edge] OK →', path.relative(REPO_ROOT, DEST_ROOT));
}

main();
