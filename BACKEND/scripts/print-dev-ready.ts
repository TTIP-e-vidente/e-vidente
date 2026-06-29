/**
 * Banner post-arranque: confirma API + DB (Supabase vs local) + pasos para Godot.
 */
import http from 'http';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';
import { loadBackendEnv } from './lib/postgres-env';

interface HealthDbPayload {
  remote?: boolean;
  migrations?: { applied?: number; expected?: number; healthy?: boolean };
}

function fetchHealthDb(port: number): Promise<HealthDbPayload | null> {
  return new Promise((resolve) => {
    const request = http.get(`http://127.0.0.1:${port}/health/db`, (response) => {
      let body = '';
      response.on('data', (chunk) => {
        body += chunk;
      });
      response.on('end', () => {
        try {
          resolve(JSON.parse(body) as HealthDbPayload);
        } catch {
          resolve(null);
        }
      });
    });
    request.on('error', () => resolve(null));
    request.setTimeout(3000, () => {
      request.destroy();
      resolve(null);
    });
  });
}

export async function printDevReadyBanner(cloudBaseUrl?: string): Promise<void> {
  const { envFile } = loadBackendEnv();
  const port = Number.parseInt(process.env.BACKEND_PORT ?? '3010', 10);
  const localBase = `http://${(process.env.BACKEND_HOST ?? 'localhost').trim()}:${port}`;
  const baseUrl = cloudBaseUrl?.trim() || localBase;
  const isCloud = Boolean(cloudBaseUrl?.trim());
  const health = isCloud ? null : await fetchHealthDb(port);

  console.log('\n═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Listo para Godot');
  console.log('═══════════════════════════════════════════');
  console.log(`  API:   ${baseUrl}${isCloud ? ' (cloud — sin terminal)' : ''}`);
  console.log(`  Env:   ${envFile}`);

  if (isCloud) {
    console.log('  DB:    Supabase (remoto)');
  } else if (health?.remote === true) {
    const migrations = health.migrations;
    const migLabel =
      migrations?.applied != null && migrations?.expected != null
        ? `${migrations.applied}/${migrations.expected}`
        : '?';
    console.log(`  DB:    Supabase (remoto) · migraciones ${migLabel}`);
  } else if (isRemotePostgres()) {
    console.log('  DB:    Supabase (remoto)');
  } else {
    console.log('  DB:    Postgres local (Docker)');
  }

  const emailEnabled = ['true', '1', 'yes'].includes(
    (process.env.EMAIL_ENABLED ?? '').trim().toLowerCase()
  );
  const brevoReady =
    emailEnabled &&
    Boolean(process.env.BREVO_API_KEY?.trim()) &&
    Boolean(process.env.BREVO_SENDER_EMAIL?.trim());
  if (brevoReady) {
    const viaEdge = Boolean(process.env.SUPABASE_ANON_KEY?.trim());
    console.log(
      `  Mail:  Brevo activo (${process.env.BREVO_SENDER_EMAIL?.trim()})${viaEdge ? ' · verify→Supabase Edge' : ' · verify→Express'}`,
    );
  } else if (emailEnabled) {
    console.log('  Mail:  EMAIL_ENABLED=true pero falta BREVO_API_KEY o sender');
  } else {
    console.log('  Mail:  desactivado (EMAIL_ENABLED=false)');
  }

  console.log('  Godot: juego/project.godot → F5');
  console.log('  Sync:  juego/config/backend.local.json actualizado');
  if (isCloud) {
    console.log('  Jobs:  Supabase pg_cron → Edge Functions');
  } else if (Boolean(process.env.SUPABASE_ANON_KEY?.trim())) {
    console.log('  Verify: Supabase Edge (npm run supabase:functions:deploy si falla)');
    console.log('  Check:  npm run integrate:status');
  } else if (health?.remote === true) {
    console.log('  Check: npm run staging:verify');
    console.log('  Cron:  GET /health/cron · npm run setup:supabase:cron');
    console.log('  Tip:   deploy Render → npm run staging:cloud -- https://...');
  }
  console.log('═══════════════════════════════════════════\n');
}

if (require.main === module) {
  printDevReadyBanner().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
