/**
 * Panel de integración: DB, Godot config, Edge Functions, Express, crons.
 * Uso: npm run integrate:status
 */
import fs from 'fs';
import path from 'path';
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  loadBackendEnv,
} from './lib/postgres-env';
import { EXPECTED_MIGRATION_COUNT } from './lib/public-tables';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';
import { fetchRemoteHealth, isLocalBackendUrl, resolvePublicBackendUrl } from './lib/cloud-backend-url';
import { isSupabaseEmailEdgeMode, canReachSupabaseEmailEdge } from '../src/config/supabase-email-mode';
import { isEmailDeliveryConfigured } from '../src/modules/email/email.config';

const BACKEND_ROOT = path.resolve(__dirname, '..');
const GODOT_CONFIG = path.resolve(BACKEND_ROOT, '../juego/config/backend.local.json');
const KEYS_LOCAL = path.resolve(BACKEND_ROOT, '.env.supabase-keys.local');

type Row = { label: string; ok: boolean; detail: string };

function row(label: string, ok: boolean, detail: string): Row {
  return { label, ok, detail };
}

async function checkEdgeHealth(): Promise<Row> {
  if (!canUseSupabaseEmailFunctions()) {
    return row('Edge Functions', false, 'Falta SUPABASE_ANON_KEY en .env.staging');
  }
  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = process.env.SUPABASE_ANON_KEY!.trim();
  try {
    const response = await fetch(`${baseUrl}/verify-email-health`, {
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
    });
    if (response.status === 404) {
      return row('Edge Functions', false, 'No desplegadas — npm run supabase:functions:deploy');
    }
    if (!response.ok) {
      return row('Edge Functions', false, `verify-email-health HTTP ${response.status}`);
    }
    const body = (await response.json()) as { delivery_configured?: boolean };
    const brevo = body.delivery_configured ? 'Brevo OK' : 'Brevo no configurado en Edge secrets';
    return row('Edge Functions', true, `${baseUrl} · ${brevo}`);
  } catch (error) {
    return row('Edge Functions', false, error instanceof Error ? error.message : String(error));
  }
}

async function checkExpress(): Promise<Row> {
  const publicUrl = resolvePublicBackendUrl();
  if (!isLocalBackendUrl(publicUrl)) {
    const health = await fetchRemoteHealth(publicUrl);
    return row(
      'Express API',
      health.ok,
      health.ok ? `${publicUrl} (cloud)` : `${publicUrl} no responde /health/ready`,
    );
  }
  const port = process.env.BACKEND_PORT ?? '3010';
  const local = `http://127.0.0.1:${port}`;
  try {
    const response = await fetch(`${local}/health`, { signal: AbortSignal.timeout(3000) });
    return row(
      'Express API',
      response.ok,
      response.ok ? `${local} (local — login/progreso)` : `HTTP ${response.status}`,
    );
  } catch {
    return row(
      'Express API',
      false,
      `${local} apagado — npm run dev (solo login/progreso; verify va por Supabase)`,
    );
  }
}

async function main(): Promise<void> {
  loadBackendEnv();
  const envPath = path.resolve(BACKEND_ROOT, process.env.ENV_FILE?.trim() || '.env.staging');
  assertSupabaseStagingEnv(envPath);

  const rows: Row[] = [];

  rows.push(
    fs.existsSync(KEYS_LOCAL)
      ? row('Keys locales', true, '.env.supabase-keys.local presente')
      : row('Keys locales', false, 'Creá .env.supabase-keys.local → npm run configure:supabase-keys'),
  );

  rows.push(
    canUseSupabaseEmailFunctions()
      ? row('SUPABASE_ANON_KEY', true, 'Configurada en .env.staging')
      : row('SUPABASE_ANON_KEY', false, 'npm run configure:supabase-keys'),
  );

  if (fs.existsSync(GODOT_CONFIG)) {
    const godot = JSON.parse(fs.readFileSync(GODOT_CONFIG, 'utf8')) as Record<string, unknown>;
    const viaSupabase = bool(godot.email_via_supabase) || str(godot.db) === 'supabase';
    const portOk = !str(godot.base_url).includes(':3000');
    rows.push(
      row(
        'Godot config',
        viaSupabase && str(godot.base_url).length > 0 && portOk && canReachSupabaseEmailEdge(),
        `base=${str(godot.base_url)} · verify→${viaSupabase ? 'supabase' : 'express'} · db=${str(godot.db)}`,
      ),
    );
  } else {
    rows.push(row('Godot config', false, 'Falta juego/config/backend.local.json — npm run sync:godot-config:staging'));
  }

  await connectSupabase({ envPath, persistToEnvFile: true, silent: true });
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  const client = await pool.connect();
  try {
    const mig = await client.query<{ count: string }>(
      'SELECT COUNT(*)::text AS count FROM schema_migrations;',
    );
    const count = Number.parseInt(mig.rows[0]?.count ?? '0', 10);
    rows.push(
      row('Migraciones', count >= EXPECTED_MIGRATION_COUNT, `${count}/${EXPECTED_MIGRATION_COUNT}`),
    );

    const cronSettings = await client.query<{ key: string; value: string }>(
      `SELECT key, value FROM private.internal_cron_settings WHERE key IN (
        'supabase_functions_url', 'supabase_anon_key', 'email_cron_secret'
      );`,
    );
    const map = new Map(cronSettings.rows.map((r) => [r.key, r.value]));
    const cronOk =
      Boolean(map.get('supabase_functions_url')?.trim()) &&
      Boolean(map.get('supabase_anon_key')?.trim()) &&
      Boolean(map.get('email_cron_secret')?.trim());
    rows.push(
      row(
        'pg_cron → Edge',
        cronOk,
        cronOk ? 'Crons apuntan a Edge Functions' : 'npm run setup:supabase:cron',
      ),
    );

    const users = await client.query<{ c: string }>('SELECT COUNT(*)::text AS c FROM users;');
    rows.push(row('Usuarios DB', true, `${users.rows[0]?.c ?? 0} en Supabase`));
  } finally {
    client.release();
    await pool.end();
  }

  rows.push(
    row(
      'Mails en Express',
      isSupabaseEmailEdgeMode(),
      isSupabaseEmailEdgeMode()
        ? 'Desactivado (correcto) — solo Edge + pg_cron'
        : 'Activo (Postgres local)',
    ),
  );

  rows.push(
    row(
      'Brevo (Edge secrets)',
      isSupabaseEmailEdgeMode() ? canReachSupabaseEmailEdge() : isEmailDeliveryConfigured(),
      isSupabaseEmailEdgeMode()
        ? 'Brevo vive en Edge Function secrets (npm run supabase:functions:deploy)'
        : isEmailDeliveryConfigured()
          ? 'OK en .env local'
          : 'Falta BREVO_*',
    ),
  );

  rows.push(await checkEdgeHealth());
  rows.push(await checkExpress());

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Integración Supabase + Godot');
  console.log('═══════════════════════════════════════════\n');

  let failed = 0;
  for (const r of rows) {
    console.log(`  ${r.ok ? '✓' : '✗'} ${r.label.padEnd(18)} ${r.detail}`);
    if (!r.ok) {
      failed += 1;
    }
  }

  console.log('\n───────────────────────────────────────────');
  console.log('  Flujo objetivo:');
  console.log('    Login/progreso → Express (local o Render)');
  console.log('    Verify OTP     → Supabase Edge Functions');
  console.log('    Jobs mail      → pg_cron → Edge internal-job');
  console.log('───────────────────────────────────────────');

  if (failed > 0) {
    console.log(`\n${failed} chequeo(s) pendientes → npm run integrate:staging\n`);
    process.exit(1);
  }
  console.log('\nIntegración OK.\n');
}

function str(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function bool(value: unknown): boolean {
  return value === true;
}

main().catch((error) => {
  console.error('\nintegrate:status falló:', error);
  process.exit(1);
});
