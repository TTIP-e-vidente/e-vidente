import { execSync } from 'child_process';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const port = process.env.BACKEND_PORT ?? '3010';

function getListeningPids(targetPort: string): number[] {
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

const pids = getListeningPids(port);
if (pids.length === 0) {
  console.log(`Ningún proceso escuchando en el puerto ${port}.`);
  process.exit(0);
}

for (const pid of pids) {
  console.log(`Deteniendo PID ${pid} en puerto ${port}...`);
  execSync(`taskkill /PID ${pid} /F`, { stdio: 'inherit' });
}

console.log(`Puerto ${port} liberado.`);
