import { isRemotePostgres } from '../../src/config/postgresPoolConfig';
import { loadBackendEnv } from './postgres-env';

const LOCAL_DOCKER_MESSAGE = `
Este proyecto usa Supabase como única base de datos (sin Docker Compose local).

  cd BACKEND
  npm run supabase:init          # primera vez
  npm run configure:supabase-keys
  npm run integrate:staging      # migrate + edge + cron + godot
  npm run dev                    # Express → Supabase + sync Godot

Verificación: npm run integrate:status
Guía: docs/SUPABASE_QUICKSTART.md
`;

/**
 * Bloquea flujos dev que dependían de Postgres Docker (.env con POSTGRES_SSL=false).
 * Excepción: el stack local-first (npm run dev / scripts/dev-local.ts) opta
 * explícitamente con ALLOW_LOCAL_POSTGRES_DEV=true — el juego separa esos
 * datos de Supabase (cuentas @local) y cae solo a Edge si el stack no está.
 */
export function assertSupabaseOnlyDev(entrypoint: string): void {
  if (isRemotePostgres()) {
    return;
  }
  const allowLocal = (process.env.ALLOW_LOCAL_POSTGRES_DEV ?? '').trim().toLowerCase();
  if (['true', '1', 'yes'].includes(allowLocal)) {
    return;
  }

  const { envFile } = loadBackendEnv();
  console.error(`\n✗ ${entrypoint} requiere Supabase (POSTGRES_SSL=true).`);
  console.error(`  Env actual: ${envFile} → Postgres local/Docker deshabilitado.\n`);
  console.error(LOCAL_DOCKER_MESSAGE.trim());
  process.exit(1);
}

export function printSupabaseOnlyDevHint(): void {
  console.log('[dev] Modo Supabase-only — DB remota, mails/jobs en Edge Functions.');
}
