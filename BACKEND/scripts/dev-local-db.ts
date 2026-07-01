import { execSync } from 'child_process';
import fs from 'fs';
import http from 'http';
import path from 'path';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';
import { loadBackendEnv } from './lib/postgres-env';
import { printDevReadyBanner } from './print-dev-ready';
import { stopDevServerOnPort } from './stop-dev-server';

const PROJECT_ROOT = path.resolve(__dirname, '..');
const LOCAL_ENV = '.env.local';
const GODOT_CONFIG_PATH = path.resolve(PROJECT_ROOT, '../juego/config/backend.local.json');

function run(command: string, env: NodeJS.ProcessEnv = process.env): void {
  execSync(command, {
    cwd: PROJECT_ROOT,
    stdio: 'inherit',
    env,
  });
}

function fetchHealth(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const request = http.get(`http://127.0.0.1:${port}/health`, (response) => {
      response.resume();
      resolve(response.statusCode === 200);
    });
    request.on('error', () => resolve(false));
    request.setTimeout(3000, () => {
      request.destroy();
      resolve(false);
    });
  });
}

/**
 * Guarda el contenido actual de backend.local.json (config Supabase/staging)
 * y registra un handler para restaurarlo al salir del proceso.
 * Así Godot queda siempre apuntando a Supabase cuando no está corriendo
 * el servidor local, y dev:local-db no pisa la config de Supabase.
 */
function registerGodotConfigRestore(): void {
  if (!fs.existsSync(GODOT_CONFIG_PATH)) {
    return;
  }

  const previousContent = fs.readFileSync(GODOT_CONFIG_PATH, 'utf8');
  let previousConfig: Record<string, unknown>;
  try {
    previousConfig = JSON.parse(previousContent) as Record<string, unknown>;
  } catch {
    return;
  }

  // Solo restaurar si la config previa era Supabase Edge (no otra local)
  if (previousConfig.api_mode !== 'supabase_edge') {
    return;
  }

  function restore(): void {
    try {
      fs.writeFileSync(GODOT_CONFIG_PATH, previousContent, 'utf8');
      console.log('\n[dev:local-db] Restaurado backend.local.json → supabase_edge (Godot OK)');
    } catch {
      // silencioso — el archivo puede no existir en entornos sin juego
    }
  }

  process.once('exit', restore);
  process.once('SIGINT', () => {
    restore();
    process.exit(0);
  });
  process.once('SIGTERM', () => {
    restore();
    process.exit(0);
  });
}

async function main(): Promise<void> {
  const envPath = path.resolve(PROJECT_ROOT, LOCAL_ENV);
  if (!fs.existsSync(envPath)) {
    throw new Error(
      `Falta ${LOCAL_ENV}. Copia BACKEND/.env.local.example a BACKEND/${LOCAL_ENV} y ajusta valores si hace falta.`
    );
  }

  process.env.ENV_FILE = LOCAL_ENV;
  loadBackendEnv();
  if (isRemotePostgres()) {
    throw new Error(`${LOCAL_ENV} debe tener POSTGRES_SSL=false para usar Postgres local.`);
  }

  const env = {
    ...process.env,
    ENV_FILE: LOCAL_ENV,
    POSTGRES_ENV_FILE: LOCAL_ENV,
  };
  const port = Number.parseInt(process.env.BACKEND_PORT ?? '3010', 10);

  // Guardar config Godot antes de pisar — restaurar automáticamente al salir
  registerGodotConfigRestore();

  console.log('[dev:local-db] Modo local - Express + Postgres Docker');
  run('docker compose --env-file .env.local up -d postgres', env);
  run('npx ts-node scripts/run-migrations.ts', env);
  run('npx ts-node scripts/sync-godot-backend-config.ts', env);

  if (await fetchHealth(port)) {
    console.log(`[dev:local-db] Ya hay backend en :${port}; reiniciando para usar ${LOCAL_ENV}.`);
    stopDevServerOnPort(String(port));
  }

  process.env.ENV_FILE = LOCAL_ENV;
  require('../src/server');
  await printDevReadyBanner();
}

main().catch((error) => {
  console.error('[dev:local-db] fallo:', (error as Error).message);
  process.exit(1);
});
