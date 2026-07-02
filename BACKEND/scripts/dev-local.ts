/**
 * Dev local-first: levanta el stack completo en esta máquina.
 *
 *   npm run dev  →  Docker Postgres (5433) + migraciones + Express (:3010)
 *                   + backend.local.json en modo auto para Godot.
 *
 * Godot (modo auto): si este Express responde, el juego lo usa (datos en el
 * Postgres local, separados de Supabase). Si no está levantado, el juego cae
 * solo a Supabase Edge. Para trabajar contra Supabase con Express local:
 * npm run dev:staging.
 */
import { execSync, spawnSync } from 'child_process';
import path from 'path';
import { Pool } from 'pg';

const PROJECT_ROOT = path.resolve(__dirname, '..');

function run(cmd: string, env: NodeJS.ProcessEnv = {}): void {
  execSync(cmd, { cwd: PROJECT_ROOT, stdio: 'inherit', env: { ...process.env, ...env } });
}

async function canConnectLocalPostgres(): Promise<boolean> {
  const pool = new Pool({
    host: process.env.POSTGRES_HOST ?? 'localhost',
    port: Number.parseInt(process.env.POSTGRES_PORT ?? '5433', 10),
    database: process.env.POSTGRES_DB ?? 'evidente_dev',
    user: process.env.POSTGRES_USER ?? 'evidente_user',
    password: process.env.POSTGRES_PASSWORD ?? 'evidente_password',
    connectionTimeoutMillis: 2500,
  });
  try {
    const client = await pool.connect();
    client.release();
    return true;
  } catch {
    return false;
  } finally {
    await pool.end();
  }
}

async function waitForPostgres(maxSeconds: number): Promise<boolean> {
  const deadline = Date.now() + maxSeconds * 1000;
  while (Date.now() < deadline) {
    if (await canConnectLocalPostgres()) {
      return true;
    }
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  return false;
}

async function main(): Promise<void> {
  process.env.ENV_FILE = process.env.ENV_FILE?.trim() || '.env';
  // Opt-in explícito al Postgres local (la política default es Supabase-only).
  process.env.ALLOW_LOCAL_POSTGRES_DEV = 'true';
  console.log('[dev:local] Stack local — Docker Postgres + Express :3010\n');

  if (!(await canConnectLocalPostgres())) {
    console.log('[dev:local] Levantando Postgres con docker compose…');
    const docker = spawnSync('docker', ['compose', 'up', '-d'], {
      cwd: PROJECT_ROOT,
      stdio: 'inherit',
      shell: true,
    });
    if (docker.status !== 0) {
      console.error(
        '\n✗ Docker no está disponible. Abrí Docker Desktop y reintentá,\n' +
          '  o usá npm run dev:staging para trabajar contra Supabase.'
      );
      process.exit(1);
    }
    if (!(await waitForPostgres(60))) {
      console.error('\n✗ Postgres local no respondió tras 60 s. Revisá docker compose logs.');
      process.exit(1);
    }
  }

  console.log('[dev:local] Migraciones…');
  run('npx ts-node scripts/run-migrations.ts');

  console.log('[dev:local] Sincronizando config de Godot (modo auto)…');
  run('npx ts-node scripts/sync-godot-backend-config.ts');

  console.log('[dev:local] Levantando Express…');
  run('npx ts-node scripts/start-dev-if-needed.ts');

  console.log(
    '\n[dev:local] Listo. Godot usará este backend (datos locales, cuentas @local).\n' +
      '            Cerrá este stack y el juego cae solo a Supabase Edge.\n' +
      '            Mails: Brevo si está en .env; si no, el código OTP sale en esta consola (dev_code).'
  );
}

main().catch((error) => {
  console.error('[dev:local] falló:', error);
  process.exit(1);
});
