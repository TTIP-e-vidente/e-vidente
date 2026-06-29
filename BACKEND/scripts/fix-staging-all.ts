/**
 * Deja staging listo de punta a punta:
 * - Migraciones Supabase
 * - Secrets + crons pg_cron
 * - Reparación mail verificado
 * - Godot config
 * - Modo cloud si hay BACKEND_BASE_URL público
 *
 * Uso:
 *   npm run staging:fix-all
 *   npm run staging:fix-all -- --cloud https://e-vidente-api.onrender.com
 */
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import {
  BACKEND_ROOT,
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
} from './lib/postgres-env';
import { fetchRemoteHealth, isLocalBackendUrl, resolvePublicBackendUrl } from './lib/cloud-backend-url';

const STAGING_ENV = '.env.staging';

function run(label: string, command: string, optional = false): void {
  console.log(`\n▶ ${label}`);
  try {
    execSync(command, {
      cwd: BACKEND_ROOT,
      stdio: 'inherit',
      env: { ...process.env, ENV_FILE: STAGING_ENV },
    });
  } catch (error) {
    if (optional) {
      console.warn(`  (opcional falló: ${label})`);
      return;
    }
    throw error;
  }
}

function upsertEnvLine(content: string, key: string, value: string): string {
  const lines = content.split(/\r?\n/);
  let found = false;
  const updated = lines.map((line) => {
    if (line.trimStart().startsWith(`${key}=`)) {
      found = true;
      return `${key}=${value}`;
    }
    return line;
  });
  if (!found) {
    updated.push(`${key}=${value}`);
  }
  return updated.join('\n');
}

function readCloudUrlFromArgs(): string | null {
  const idx = process.argv.indexOf('--cloud');
  if (idx >= 0 && process.argv[idx + 1]) {
    return process.argv[idx + 1].trim().replace(/\/+$/, '');
  }
  return null;
}

function printRenderChecklist(): void {
  console.log(`
═══════════════════════════════════════════
  Falta API en la nube (sin terminal local)
═══════════════════════════════════════════

1. Render → New Web Service → repo e-vidente
   Blueprint: BACKEND/render.yaml (rootDir BACKEND)

2. Variables (copiá de BACKEND/.env.staging — NO regeneres JWT si usás la misma DB):
   POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_SSL=true
   SUPABASE_PROJECT_REF, JWT_SECRET (el mismo que staging)
   EMAIL_CRON_SECRET (el mismo que staging)
   BREVO_API_KEY, BREVO_SENDER_EMAIL, BREVO_SENDER_NAME
   EMAIL_ENABLED=true
   BACKEND_BASE_URL=https://TU-SERVICIO.onrender.com

3. Deploy → esperá GET /health/ready = 200

4. Acá en tu PC (una sola vez):
   npm run staging:fix-all -- --cloud https://TU-SERVICIO.onrender.com

5. Abrí Godot → F5 (sin npm run dev)

Mientras tanto (solo dev con PC prendida):
   npm run dev   → terminal local + localhost:3010
`);
}

async function assertUsersOk(): Promise<void> {
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  const client = await pool.connect();
  try {
    const users = await client.query<{
      username: string;
      mail: string | null;
      mail_verified_at: Date | null;
    }>(
      `
        SELECT username, mail, mail_verified_at
        FROM users
        WHERE username IN ('agus', 'margo')
        ORDER BY username;
      `
    );
    console.log('\n▶ Cuentas staging:');
    for (const row of users.rows) {
      const st = row.mail_verified_at ? 'mail verificado' : 'mail sin verificar';
      console.log(`  • ${row.username}: ${row.mail ?? '(sin mail)'} — ${st}`);
    }
  } finally {
    client.release();
    await pool.end();
  }
}

async function main(): Promise<void> {
  const cloudArg = readCloudUrlFromArgs();
  const staging = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(staging.envPath);

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Arreglar staging completo');
  console.log('═══════════════════════════════════════════');

  if (cloudArg) {
    if (isLocalBackendUrl(cloudArg)) {
      console.error('ERROR: --cloud debe ser URL pública https://...');
      process.exit(1);
    }
    let content = fs.readFileSync(staging.envPath, 'utf8');
    content = upsertEnvLine(content, 'BACKEND_BASE_URL', cloudArg);
    fs.writeFileSync(staging.envPath, content.endsWith('\n') ? content : `${content}\n`, 'utf8');
    process.env.BACKEND_BASE_URL = cloudArg;
    console.log(`\nBACKEND_BASE_URL → ${cloudArg}`);
  }

  run('Sync secrets .env → .env.staging', 'npx ts-node scripts/sync-staging-secrets.ts');

  const keysLocal = path.resolve(BACKEND_ROOT, '.env.supabase-keys.local');
  if (fs.existsSync(keysLocal)) {
    run('Supabase keys → .env.staging', 'npx ts-node scripts/configure-supabase-api-keys.ts');
  }

  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true });

  run('Migraciones SQL (001…033)', 'npx ts-node scripts/run-migrations.ts');
  run('Crons Supabase (pg_cron)', 'npm run setup:supabase:cron');
  run('Edge Functions verify-email (Supabase)', 'npm run supabase:functions:deploy', true);
  run('Reparar mails verificados (OTP usado)', 'npx ts-node scripts/repair-mail-verification.ts -- --apply', true);
  run('Verificar schema + RLS + jobs', 'npm run verify:supabase');

  const publicUrl = resolvePublicBackendUrl();
  const cloudMode = !isLocalBackendUrl(publicUrl);

  if (cloudMode) {
    console.log(`\n▶ Modo cloud: ${publicUrl}`);
    const health = await fetchRemoteHealth(publicUrl);
    if (!health.ok) {
      console.error('\nERROR: BACKEND_BASE_URL no responde /health/db');
      console.error('Deploy en Render primero o corregí la URL.');
      process.exit(1);
    }
    run('Sync Godot → API cloud', 'npx ts-node scripts/sync-godot-backend-config.ts');
    console.log('\n✓ Modo sin terminal: Godot usa la API en la nube.');
    console.log('  pg_cron Supabase dispara la misma URL para rachas.');
  } else {
    run('Sync Godot → localhost (dev)', 'npx ts-node scripts/sync-godot-backend-config.ts');
    printRenderChecklist();
  }

  await assertUsersOk();
  run('Panel integración', 'npx ts-node scripts/integration-status.ts', true);

  console.log('\n═══════════════════════════════════════════');
  console.log('  staging:fix-all completado');
  console.log('═══════════════════════════════════════════');
}

main().catch((error) => {
  console.error('\nstaging:fix-all falló:', error);
  process.exit(1);
});
