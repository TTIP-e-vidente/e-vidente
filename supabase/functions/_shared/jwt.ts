import * as jose from 'npm:jose@5';

export interface AccessTokenPayload {
  sub: string;
  username: string;
}

export async function verifyExpressAccessToken(
  authorization: string | null,
): Promise<AccessTokenPayload> {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AuthError('Invalid token');
  }

  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    throw new AuthError('Invalid token');
  }

  const secret = Deno.env.get('JWT_SECRET')?.trim();
  if (!secret) {
    throw new ConfigError('JWT_SECRET not configured');
  }

  const key = new TextEncoder().encode(secret);
  const { payload } = await jose.jwtVerify(token, key);

  if (
    typeof payload.sub !== 'string' ||
    typeof payload.username !== 'string'
  ) {
    throw new AuthError('Invalid token');
  }

  return { sub: payload.sub, username: payload.username };
}

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthError';
  }
}

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigError';
  }
}

export function requireAnonKey(req: Request): void {
  // SUPABASE_ANON_KEY viene por defecto en Edge (dashboard → Default secrets).
  const expected =
    Deno.env.get('SUPABASE_ANON_KEY')?.trim() ||
    readLegacyAnonFromPublishableKeys();
  if (!expected) {
    return;
  }
  const provided = req.headers.get('apikey')?.trim();
  if (provided && provided !== expected) {
    throw new AuthError('Invalid apikey');
  }
}

function readLegacyAnonFromPublishableKeys(): string {
  const raw = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')?.trim();
  if (!raw) {
    return '';
  }
  try {
    const parsed = JSON.parse(raw) as Record<string, string>;
    return (
      parsed.anon?.trim() ||
      parsed.default?.trim() ||
      Object.values(parsed).find((v) => typeof v === 'string' && v.startsWith('eyJ'))?.trim() ||
      ''
    );
  } catch {
    return '';
  }
}
