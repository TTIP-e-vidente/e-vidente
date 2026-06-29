import { resolveLogoSrc } from '../email-assets.ts';

export function emailLogoBlock(width = 128): string {
  const src = resolveLogoSrc('cid');
  if (!src) {
    return `<p style="margin:0 0 14px;font-family:'Rubik',Arial,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;color:#c7d6a8;">E-VIDENTE</p>`;
  }
  return `<img src="${src}" alt="E-VIDENTE" width="${width}" style="display:block;margin:0 auto 16px;border:0;height:auto;max-width:${width}px;" />`;
}

export function resolveEmailLogoSrc(): string {
  return resolveLogoSrc('embed');
}
