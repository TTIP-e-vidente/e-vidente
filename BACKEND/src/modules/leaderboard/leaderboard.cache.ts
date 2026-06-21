/**
 * Cache en memoria con TTL para el leaderboard.
 *
 * - Sin dependencias externas (no Redis): adecuado para proceso single-node.
 * - Stale-while-revalidate: devuelve datos stale mientras el background refresh corre.
 * - Invalidación explícita por scope cuando el refresh finaliza.
 */

const DEFAULT_TTL_MS = 60_000;        // 60 segundos frescos
const STALE_TTL_MS   = 5 * 60_000;   // 5 minutos de stale tolerable

interface CacheEntry<T> {
  data: T;
  storedAt: number;
  ttlMs: number;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const store = new Map<string, CacheEntry<any>>();

function isFresh(entry: CacheEntry<unknown>): boolean {
  return Date.now() - entry.storedAt < entry.ttlMs;
}

function isStale(entry: CacheEntry<unknown>): boolean {
  const age = Date.now() - entry.storedAt;
  return age >= entry.ttlMs && age < STALE_TTL_MS;
}

export function cacheGet<T>(key: string): { data: T; stale: boolean } | null {
  const entry = store.get(key) as CacheEntry<T> | undefined;
  if (!entry) return null;
  if (isFresh(entry)) return { data: entry.data, stale: false };
  if (isStale(entry)) return { data: entry.data, stale: true };
  store.delete(key);
  return null;
}

export function cacheSet<T>(key: string, data: T, ttlMs = DEFAULT_TTL_MS): void {
  store.set(key, { data, storedAt: Date.now(), ttlMs });
}

/**
 * Invalida todas las entradas de un scope, o toda la cache si no se especifica.
 */
export function cacheInvalidate(scopePrefix?: string): void {
  if (!scopePrefix) {
    store.clear();
    return;
  }
  for (const key of store.keys()) {
    if (key.startsWith(scopePrefix + ':')) {
      store.delete(key);
    }
  }
}

export function cacheStats(): { size: number; keys: string[] } {
  return { size: store.size, keys: [...store.keys()] };
}
