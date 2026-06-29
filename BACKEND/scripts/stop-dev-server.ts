import { execSync } from 'child_process';
import { loadBackendEnv } from './lib/postgres-env';

loadBackendEnv();

const port = process.env.BACKEND_PORT ?? '3010';

export function getListeningPids(targetPort: string): number[] {
  try {
    const output = execSync(`netstat -ano | findstr ":${targetPort}"`, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    const pids = new Set<number>();
    for (const line of output.split(/\r?\n/)) {
      if (!line.includes('LISTENING')) {
        continue;
      }
      const parts = line.trim().split(/\s+/);
      const pid = Number.parseInt(parts[parts.length - 1] ?? '', 10);
      if (!Number.isNaN(pid)) {
        pids.add(pid);
      }
    }
    return [...pids];
  } catch {
    return [];
  }
}

export function stopDevServerOnPort(targetPort: string = port): boolean {
  const pids = getListeningPids(targetPort);
  if (pids.length === 0) {
    return false;
  }

  for (const pid of pids) {
    console.log(`Deteniendo PID ${pid} en puerto ${targetPort}...`);
    execSync(`taskkill /PID ${pid} /F`, { stdio: 'inherit' });
  }

  console.log(`Puerto ${targetPort} liberado.`);
  return true;
}

function main(): void {
  if (!stopDevServerOnPort(port)) {
    console.log(`Ningún proceso escuchando en el puerto ${port}.`);
  }
}

if (require.main === module) {
  main();
}
