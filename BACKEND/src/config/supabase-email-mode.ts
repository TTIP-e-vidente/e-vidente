import { loadEnvFile } from './load-env';
import { isRemotePostgres } from './postgresPoolConfig';
import { resolveSupabaseClientApiKey } from './supabase-edge-client';

loadEnvFile();

function parseDisabledFlag(value: string | undefined): boolean {
  const normalized = (value ?? '').trim().toLowerCase();
  return normalized === 'false' || normalized === '0' || normalized === 'no';
}

/** Mails transaccionales y jobs corren en Supabase Edge, no en Express. */
export function isSupabaseEmailEdgeMode(): boolean {
  if (!isRemotePostgres()) {
    return false;
  }
  if (parseDisabledFlag(process.env.EMAIL_VIA_SUPABASE_EDGE)) {
    return false;
  }
  return true;
}

/** Auth y health del juego vía Edge Functions (sin Express). */
export function isSupabaseApiEdgeMode(): boolean {
  if (!isSupabaseEmailEdgeMode()) {
    return false;
  }
  if (parseDisabledFlag(process.env.SUPABASE_API_EDGE)) {
    return false;
  }
  return true;
}

export function canReachSupabaseEmailEdge(): boolean {
  const clientKey = resolveSupabaseClientApiKey();
  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim() ?? '';
  return clientKey.length > 0 && projectRef.length > 0 && !projectRef.includes('TU_');
}

/** Express no debe enviar mails ni correr cola outbound cuando Edge está activo. */
export function shouldRunExpressEmailDelivery(): boolean {
  return !isSupabaseEmailEdgeMode();
}
