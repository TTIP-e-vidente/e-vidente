/** Clave pública Supabase para Godot/smokes/Edge gateway. */
export function resolveSupabaseClientApiKey(): string {
  const publishable = process.env.SUPABASE_PUBLISHABLE_KEY?.trim() ?? '';
  if (publishable) {
    return publishable;
  }
  return process.env.SUPABASE_ANON_KEY?.trim() ?? '';
}

export function isLocalBackendUrl(url: string): boolean {
  const trimmed = url.trim();
  if (!trimmed) {
    return true;
  }
  return /^https?:\/\/(127\.0\.0\.1|localhost)(:|\/|$)/i.test(trimmed);
}
