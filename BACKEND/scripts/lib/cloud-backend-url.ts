const LOCALHOST_PATTERN = /^(https?:\/\/)?(127\.0\.0\.1|localhost)(:\d+)?(\/|$)/i;

export function isLocalBackendUrl(url: string | null | undefined): boolean {
  if (!url) {
    return true;
  }
  return LOCALHOST_PATTERN.test(url.trim());
}

export function resolvePublicBackendUrl(): string {
  const explicit = (
    process.env.BACKEND_BASE_URL ??
    process.env.PUBLIC_API_URL ??
    process.env.API_PUBLIC_URL ??
    ''
  ).trim();
  if (explicit.length > 0) {
    return explicit.replace(/\/+$/, '');
  }
  const port = process.env.BACKEND_PORT ?? '3010';
  const host = (process.env.BACKEND_HOST ?? 'localhost').trim();
  return `http://${host}:${port}`;
}

export function resolveGodotBackendUrl(): string {
  const publicUrl = resolvePublicBackendUrl();
  if (!isLocalBackendUrl(publicUrl)) {
    return publicUrl;
  }
  return publicUrl;
}

export async function fetchRemoteHealth(baseUrl: string): Promise<{
  ok: boolean;
  remote?: boolean;
  migrations?: { applied?: number; expected?: number; healthy?: boolean };
}> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(`${baseUrl.replace(/\/+$/, '')}/health/db`, {
      signal: controller.signal,
    });
    if (!response.ok) {
      return { ok: false };
    }
    const payload = (await response.json()) as {
      remote?: boolean;
      migrations?: { applied?: number; expected?: number; healthy?: boolean };
    };
    return {
      ok: true,
      remote: payload.remote,
      migrations: payload.migrations,
    };
  } catch {
    return { ok: false };
  } finally {
    clearTimeout(timeout);
  }
}
