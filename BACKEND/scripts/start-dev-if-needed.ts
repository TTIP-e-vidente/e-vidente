import dotenv from 'dotenv';
import http from 'http';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const port = Number.parseInt(process.env.BACKEND_PORT ?? '3010', 10);

function isBackendHealthy(): Promise<boolean> {
  return new Promise((resolve) => {
    const request = http.get(`http://127.0.0.1:${port}/health`, (response) => {
      let body = '';
      response.on('data', (chunk) => {
        body += chunk;
      });
      response.on('end', () => {
        try {
          resolve(JSON.parse(body).status === 'ok');
        } catch {
          resolve(false);
        }
      });
    });

    request.on('error', () => resolve(false));
    request.setTimeout(2000, () => {
      request.destroy();
      resolve(false);
    });
  });
}

async function main(): Promise<void> {
  if (await isBackendHealthy()) {
    console.log(`E-VIDENTE backend ya corre en http://localhost:${port}`);
    console.log('No hace falta levantar otro. Para reiniciar: npm run dev:restart');
    return;
  }

  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../src/server');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
