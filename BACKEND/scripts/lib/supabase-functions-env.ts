/** Construye DATABASE_URL para Supabase Edge Functions desde POSTGRES_* del backend. */
import { resolveSupabaseClientApiKey } from '../../src/config/supabase-edge-client';

export { resolveSupabaseClientApiKey };

export function buildPostgresDatabaseUrl(): string {
  const host = process.env.POSTGRES_HOST?.trim();
  const port = process.env.POSTGRES_PORT?.trim() || '5432';
  const user = process.env.POSTGRES_USER?.trim();
  const password = process.env.POSTGRES_PASSWORD?.trim();
  const database = process.env.POSTGRES_DB?.trim() || 'postgres';

  if (!host || !user || !password) {
    throw new Error(
      'Faltan POSTGRES_HOST, POSTGRES_USER o POSTGRES_PASSWORD para DATABASE_URL de Edge Functions',
    );
  }

  return `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${database}?sslmode=require`;
}

export function resolveSupabaseFunctionsUrl(projectRef?: string): string {
  const ref = projectRef?.trim() || process.env.SUPABASE_PROJECT_REF?.trim() || '';
  if (!ref || ref.includes('TU_')) {
    return '';
  }
  return `https://${ref}.supabase.co/functions/v1`;
}

export function collectSupabaseClientApiKeys(): string[] {
  const keys = new Set<string>();
  for (const key of [
    process.env.SUPABASE_PUBLISHABLE_KEY?.trim(),
    process.env.SUPABASE_ANON_KEY?.trim(),
  ]) {
    if (key) {
      keys.add(key);
    }
  }
  return [...keys];
}

export function canUseSupabaseEmailFunctions(): boolean {
  const clientKey = resolveSupabaseClientApiKey();
  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim() ?? '';
  return clientKey.length > 0 && projectRef.length > 0 && !projectRef.includes('TU_');
}
