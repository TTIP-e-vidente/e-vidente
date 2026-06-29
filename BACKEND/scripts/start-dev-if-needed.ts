import http from 'http';
import { ensurePostgres } from './ensure-postgres';
import { loadBackendEnv } from './lib/postgres-env';
import { printDevReadyBanner } from './print-dev-ready';
import { stopDevServerOnPort } from './stop-dev-server';

loadBackendEnv();

const port = Number.parseInt(process.env.BACKEND_PORT ?? '3010', 10);

function envBrevoShouldBeActive(): boolean {
  const emailEnabled = ['true', '1', 'yes'].includes(
    (process.env.EMAIL_ENABLED ?? '').trim().toLowerCase()
  );
  return (
    emailEnabled &&
    Boolean(process.env.BREVO_API_KEY?.trim()) &&
    Boolean(process.env.BREVO_SENDER_EMAIL?.trim())
  );
}

function fetchJson(pathname: string): Promise<Record<string, unknown> | null> {
  return new Promise((resolve) => {
    const request = http.get(`http://127.0.0.1:${port}${pathname}`, (response) => {
      let body = '';
      response.on('data', (chunk) => {
        body += chunk;
      });
      response.on('end', () => {
        try {
          resolve(JSON.parse(body) as Record<string, unknown>);
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

async function isBackendHealthy(): Promise<boolean> {
  const payload = await fetchJson('/health');
  return payload?.status === 'ok';
}

async function isServerEmailConfigStale(): Promise<boolean> {
  if (!envBrevoShouldBeActive()) {
    return false;
  }
  const payload = await fetchJson('/health/email');
  if (!payload) {
    return false;
  }
  return payload.delivery_configured !== true;
}

async function main(): Promise<void> {
  if (await isBackendHealthy()) {
    if (await isServerEmailConfigStale()) {
      console.log(
        `[dev] El proceso en :${port} no tiene Brevo cargado (ENV_FILE distinto o env viejo). Reiniciando...`
      );
      stopDevServerOnPort(String(port));
    } else {
      console.log(`E-VIDENTE backend ya corre en http://localhost:${port}`);
      console.log('No hace falta levantar otro. Para reiniciar: npm run dev:restart');
      await printDevReadyBanner();
      return;
    }
  }

  await ensurePostgres();

  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../src/server');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
