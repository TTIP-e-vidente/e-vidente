/**
 * Genera .env.production desde .env.staging (mismo Supabase de staging o base para prod).
 * No copia secrets a git — solo archivos locales gitignored.
 *
 * Uso:
 *   npm run prod:init-env
 */
import fs from 'fs';
import path from 'path';
import { BACKEND_ROOT } from './lib/postgres-env';

const STAGING = path.resolve(BACKEND_ROOT, '.env.staging');
const PROD = path.resolve(BACKEND_ROOT, '.env.production');

function parseEnv(content: string): Map<string, string> {
  const map = new Map<string, string>();
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }
    const eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    map.set(trimmed.slice(0, eq), trimmed.slice(eq + 1));
  }
  return map;
}

function serializeEnv(map: Map<string, string>, header: string[]): string {
  const lines = [...header, ''];
  const keys = [...map.keys()];
  for (const key of keys) {
    lines.push(`${key}=${map.get(key) ?? ''}`);
  }
  return `${lines.join('\n')}\n`;
}

function main(): void {
  if (!fs.existsSync(STAGING)) {
    console.error('ERROR: no existe .env.staging. Corré npm run supabase:init primero.');
    process.exit(1);
  }

  const staging = parseEnv(fs.readFileSync(STAGING, 'utf8'));
  const prod = new Map(staging);

  prod.set('NODE_ENV', 'production');
  prod.set('EMAIL_PROCESS_ON_STARTUP', 'false');

  if (!prod.get('BACKEND_BASE_URL')?.trim()) {
    prod.set('BACKEND_BASE_URL', 'https://TU-SERVICIO.onrender.com');
  }

  if (!prod.get('SUPABASE_ANON_KEY')?.trim()) {
    prod.set('SUPABASE_ANON_KEY', '');
  }

  const header = [
    '# Generado por npm run prod:init-env',
    '# Revisá BACKEND_BASE_URL después de crear el servicio en Render',
    '# SUPABASE_ANON_KEY: Supabase Dashboard → Settings → API → anon public',
    '# En prod real: rotá JWT_SECRET y EMAIL_CRON_SECRET respecto a staging',
  ];

  if (fs.existsSync(PROD)) {
    console.warn('AVISO: .env.production ya existe — no se sobrescribió.');
    console.warn('  Borrá el archivo manualmente si querés regenerarlo.');
    process.exit(0);
  }

  fs.writeFileSync(PROD, serializeEnv(prod, header), 'utf8');
  console.log(`✓ Creado ${PROD}`);
  console.log('\nCompletá manualmente:');
  if (!staging.get('SUPABASE_ANON_KEY')?.trim()) {
    console.log('  • SUPABASE_ANON_KEY (obligatorio para verify en Godot + crons Edge)');
  }
  console.log('  • BACKEND_BASE_URL (URL de Render después del deploy)');
  console.log('\nSiguiente: npm run prod:bootstrap');
}

main();
