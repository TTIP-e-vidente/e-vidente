import * as jose from 'npm:jose@5';

export interface AccessTokenPayload {
  sub: string;
  username: string;
  scope?: string;
}

// Scope del token acotado que devuelve auth-login cuando el mail no está
// verificado: solo habilita verify-email-request/confirm y player-email-status.
export const VERIFICATION_TOKEN_SCOPE = 'email_verification';

export async function verifyExpressAccessToken(
  authorization: string | null,
  options?: { allowScopes?: string[] },
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
  try {
    const { payload } = await jose.jwtVerify(token, key);

    if (
      typeof payload.sub !== 'string' ||
      typeof payload.username !== 'string'
    ) {
      throw new AuthError('Invalid token');
    }

    const scope = typeof payload.scope === 'string' ? payload.scope : undefined;
    // Por defecto los tokens con scope se rechazan: solo los endpoints que
    // declaran allowScopes explícitamente aceptan el token acotado.
    if (scope && !(options?.allowScopes ?? []).includes(scope)) {
      throw new AuthError('Invalid token');
    }

    return { sub: payload.sub, username: payload.username, ...(scope ? { scope } : {}) };
  } catch (error) {
    if (error instanceof AuthError) {
      throw error;
    }
    throw new AuthError('Invalid token');
  }
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

function extractBearer(authorization: string | null): string {
  if (!authorization?.startsWith('Bearer ')) {
    return '';
  }
  return authorization.slice('Bearer '.length).trim();
}

function collectAcceptedApiKeys(): Set<string> {
  const keys = new Set<string>();

  const gameKeys = Deno.env.get('GAME_CLIENT_API_KEYS')?.split(',') ?? [];
  for (const key of gameKeys) {
    const trimmed = key.trim();
    if (trimmed) {
      keys.add(trimmed);
    }
  }

  for (const envName of ['SUPABASE_ANON_KEY', 'SUPABASE_PUBLISHABLE_KEY'] as const) {
    const value = Deno.env.get(envName)?.trim();
    if (value) {
      keys.add(value);
    }
  }

  const legacy = readLegacyAnonFromPublishableKeys();
  if (legacy) {
    keys.add(legacy);
  }

  const raw = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')?.trim();
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Record<string, string>;
      for (const value of Object.values(parsed)) {
        if (typeof value === 'string' && value.trim()) {
          keys.add(value.trim());
        }
      }
    } catch {
      // ignore malformed JSON
    }
  }

  return keys;
}

export function requireAnonKey(req: Request): void {
  const accepted = collectAcceptedApiKeys();
  if (accepted.size === 0) {
    return;
  }

  const provided = req.headers.get('apikey')?.trim() || extractBearer(req.headers.get('Authorization'));
  if (!provided) {
    return;
  }

  if (!accepted.has(provided)) {
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
