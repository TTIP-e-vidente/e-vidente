import { execSync } from 'child_process';
import dotenv from 'dotenv';
import path from 'path';

const PROJECT_ROOT = path.resolve(__dirname, '..');
const envFile = process.argv[2];
const commandParts = process.argv.slice(3);

if (!envFile || commandParts.length === 0) {
  console.error('Uso: npx ts-node scripts/with-env-file.ts <.env.staging> <comando...>');
  console.error('Ej: npx ts-node scripts/with-env-file.ts .env.staging npm run smoke:api');
  process.exit(1);
}

const envPath = path.resolve(PROJECT_ROOT, envFile);
dotenv.config({ path: envPath });

execSync(commandParts.join(' '), {
  cwd: PROJECT_ROOT,
  stdio: 'inherit',
  env: {
    ...process.env,
    ENV_FILE: envFile,
  },
});
