import dotenv from 'dotenv';
import path from 'path';

let loaded = false;

/** Carga BACKEND/<ENV_FILE|.env> una sola vez. Debe ejecutarse antes del pool de pg. */
export function loadEnvFile(): string {
  if (loaded) {
    return process.env.ENV_FILE?.trim() || '.env';
  }

  const envFile = process.env.ENV_FILE?.trim() || '.env';
  dotenv.config({ path: path.resolve(process.cwd(), envFile) });
  process.env.ENV_FILE = envFile;
  loaded = true;
  return envFile;
}
