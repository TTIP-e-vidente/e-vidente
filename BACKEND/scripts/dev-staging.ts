import dotenv from 'dotenv';
import path from 'path';
import { execSync } from 'child_process';

const PROJECT_ROOT = path.resolve(__dirname, '..');
const STAGING_ENV = '.env.staging';

dotenv.config({ path: path.resolve(PROJECT_ROOT, STAGING_ENV) });
process.env.ENV_FILE = STAGING_ENV;

execSync('npx ts-node scripts/sync-godot-backend-config.ts', {
  cwd: PROJECT_ROOT,
  stdio: 'inherit',
  env: { ...process.env },
});

execSync('npx ts-node scripts/start-dev-if-needed.ts', {
  cwd: PROJECT_ROOT,
  stdio: 'inherit',
  env: { ...process.env },
});
