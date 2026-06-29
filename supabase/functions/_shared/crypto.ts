const VERIFICATION_CODE_LENGTH = 6;

export function generateNumericCode(): string {
  const max = 10 ** VERIFICATION_CODE_LENGTH;
  const raw = crypto.getRandomValues(new Uint32Array(1))[0] % max;
  return String(raw).padStart(VERIFICATION_CODE_LENGTH, '0');
}

export async function hashCode(code: string): Promise<string> {
  const data = new TextEncoder().encode(code);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const bufA = enc.encode(a);
  const bufB = enc.encode(b);
  if (bufA.length !== bufB.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < bufA.length; i += 1) {
    diff |= bufA[i] ^ bufB[i];
  }
  return diff === 0;
}

export function normalizeMail(value: string | null | undefined): string {
  if (value == null) {
    return '';
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed.toLowerCase() : '';
}
