/**
 * Contratos remotos de la Platform V1 (Godot ↔ Backend/Edge ↔ Supabase).
 *
 * Fuente de verdad de los DTOs y del catálogo de errores canónicos.
 * Espejo Deno para Edge Functions: supabase/functions/_shared/contracts.ts
 * (mantener ambos a mano; son tipos sin lógica).
 *
 * Documentación de flujo: BACKEND/docs/AUTH_EMAIL_VERIFICATION.md,
 * EMAIL_OUTBOX_AND_RETRIES.md, AVATARS_STORAGE.md, LOCAL_FIRST_SYNC.md.
 */

// ─── Errores canónicos ────────────────────────────────────────────────────────

export const CANONICAL_API_ERRORS = [
  'EMAIL_NOT_VERIFIED', // login bloqueado: mail sin verificar (403)
  'INVALID_CREDENTIALS', // credenciales o token inválidos (401)
  'EMAIL_ALREADY_USED', // alias canónico de DUPLICATE_MAIL (409)
  'USERNAME_ALREADY_USED', // alias canónico de DUPLICATE_USERNAME (409)
  'OTP_INVALID', // alias canónico de INVALID_CODE (422)
  'OTP_EXPIRED', // alias canónico de CODE_EXPIRED (422)
  'OTP_TOO_MANY_ATTEMPTS', // alias canónico de TOO_MANY_ATTEMPTS (429)
  'OTP_RATE_LIMITED', // alias canónico de RATE_LIMITED (429)
  'AVATAR_TOO_LARGE', // avatar > 3 MB reales (413)
  'AVATAR_UNSUPPORTED_MIME', // MIME fuera de png/jpeg/webp (400)
  'STORAGE_UNAVAILABLE', // Storage caído y fallback base64 deshabilitado (503)
  'SYNC_DUPLICATE_IGNORED', // run con clientRunId ya aplicado (200, informativo)
  'REMOTE_UNAVAILABLE' // el cliente no pudo alcanzar el backend (solo cliente)
] as const;

export type CanonicalApiErrorCode = (typeof CANONICAL_API_ERRORS)[number];

/**
 * Códigos legacy que siguen viajando por el wire y su equivalente canónico.
 * El cliente (RemoteErrorMapper.gd) normaliza con esta tabla; el server puede
 * seguir emitiendo los legacy sin romper compatibilidad.
 */
export const LEGACY_ERROR_ALIASES: Record<string, CanonicalApiErrorCode> = {
  DUPLICATE_MAIL: 'EMAIL_ALREADY_USED',
  DUPLICATE_USERNAME: 'USERNAME_ALREADY_USED',
  INVALID_CODE: 'OTP_INVALID',
  CODE_EXPIRED: 'OTP_EXPIRED',
  TOO_MANY_ATTEMPTS: 'OTP_TOO_MANY_ATTEMPTS',
  RATE_LIMITED: 'OTP_RATE_LIMITED',
  PAYLOAD_TOO_LARGE: 'AVATAR_TOO_LARGE'
};

export interface CanonicalApiError {
  /** Mensaje humano (es-AR). */
  error: string;
  /** Código estable para branching del cliente. */
  code: CanonicalApiErrorCode | string;
  /** Campos extra según el código (p. ej. verification en EMAIL_NOT_VERIFIED). */
  [key: string]: unknown;
}

// ─── Auth / usuario ───────────────────────────────────────────────────────────

export interface PublicUserDTO {
  id: string;
  username: string;
  name: string;
  mail: string | null;
  birth_date: string | null; // YYYY-MM-DD
  email_notifications_enabled: boolean;
  mail_verified_at: string | null; // ISO-8601 o null si no verificado
}

export interface AuthUserDTO {
  user: PublicUserDTO;
  /** JWT completo. Ausente cuando el login devuelve EMAIL_NOT_VERIFIED. */
  accessToken: string;
  verification?: VerificationState;
}

/** Respuesta 403 EMAIL_NOT_VERIFIED del login. */
export interface EmailNotVerifiedResponse extends CanonicalApiError {
  code: 'EMAIL_NOT_VERIFIED';
  user: PublicUserDTO;
  verification: VerificationState;
  /**
   * JWT acotado (claim scope=email_verification). Solo lo aceptan
   * verify-email-request, verify-email-confirm y player-email-status.
   * verify-email-confirm exitoso devuelve un accessToken completo.
   */
  verification_token: string;
}

export type VerificationSendStatus =
  | 'sent'
  | 'skipped'
  | 'dev_console'
  | 'rate_limited'
  | 'no_mail'
  | 'send_failed'
  | 'not_requested';

export interface VerificationState {
  code_send_status: VerificationSendStatus;
  cooldown_seconds: number;
  message: string;
  expires_minutes: number;
}

// ─── Email outbox ─────────────────────────────────────────────────────────────

export type EmailDeliveryState = 'pending' | 'sending' | 'sent' | 'failed';

export type EmailTemplateKeyDTO =
  | 'welcome'
  | 'account_verified'
  | 'streak_at_risk'
  | 'streak_lost'
  | 'email_verification'
  | 'mail_changed';

// ─── Avatar ───────────────────────────────────────────────────────────────────

export interface AvatarDTO {
  /** Base64 del contenido (se resuelve on-demand desde Storage o legacy). */
  data: string | null;
  mimeType: 'image/png' | 'image/jpeg' | 'image/webp' | null;
  /** Cache busting: cambia en cada upload. */
  updatedAt?: string;
}

export const AVATAR_ALLOWED_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp'] as const;
export const AVATAR_MAX_BYTES = 3 * 1024 * 1024;

// ─── Sync de progreso local-first ────────────────────────────────────────────

export interface ProgressSyncItem {
  /** Clave de idempotencia generada por Godot. Obligatoria. Máx 120 chars. */
  clientRunId: string;
  restriction: string; // CELIAQUIA | VEG | VYG | KETO
  expToAdd?: number;
  nodeId?: string | null;
  gameType?: string;
  accuracy?: number; // 0..100
  score?: number;
  completed?: boolean;
  correctAnswers?: number | null;
  wrongAnswers?: number | null;
  durationSeconds?: number | null;
  finishedAt?: string | null; // ISO-8601 UTC
  localDay?: string | null; // YYYY-MM-DD, día local del jugador (racha)
}

export interface ProgressSyncRequest {
  items: ProgressSyncItem[]; // máx 50
}

export interface ProgressSyncItemResult {
  clientRunId: string;
  ok: boolean;
  /** true = SYNC_DUPLICATE_IGNORED: ya estaba aplicado, no duplica EXP. */
  duplicate?: boolean;
  data?: unknown;
  error?: string;
}

export interface ProgressSyncResponse {
  /** true si ningún ítem falló. */
  synced: boolean;
  processed: number;
  createdSessions: number;
  ignoredDuplicates: number;
  results: ProgressSyncItemResult[];
  /** Compat con clientes previos. */
  summary: { total: number; synced: number; failed: number };
  /** Estado consolidado (user, profile, streak, progress, nodos, juegos). */
  progressSummary: unknown | null;
  progress: unknown | null;
  streak: unknown | null;
}
