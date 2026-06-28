/**
 * Crea BACKEND/.env.staging desde el example si no existe.
 *
 * Uso: npm run supabase:init
 */
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { BACKEND_ROOT } from './lib/postgres-env';
import {
  hasFailedChecks,
  printEnvChecks,
  validateSupabaseEnvFields,
} from './lib/supabase-env';

const STAGING_ENV = '.env.staging';
const STAGING_EXAMPLE = '.env.staging.example';

function main(): void {
  const examplePath = path.resolve(BACKEND_ROOT, STAGING_EXAMPLE);
  const stagingPath = path.resolve(BACKEND_ROOT, STAGING_ENV);

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Init Supabase (.env.staging)');
  console.log('═══════════════════════════════════════════\n');

  if (!fs.existsSync(examplePath)) {
    console.error(`ERROR: no existe ${STAGING_EXAMPLE}`);
    process.exit(1);
  }

  if (fs.existsSync(stagingPath)) {
    console.log(`Ya existe ${STAGING_ENV} — no se sobrescribe.\n`);
  } else {
    fs.copyFileSync(examplePath, stagingPath);
    console.log(`Creado ${STAGING_ENV} desde ${STAGING_EXAMPLE}\n`);
  }

  console.log('Completá en .env.staging:');
  console.log('  1. POSTGRES_HOST=db.<TU_REF>.supabase.co  (o solo SUPABASE_PROJECT_REF=<ref>)');
  console.log('  2. POSTGRES_PASSWORD=<password del proyecto>');
  console.log('  3. JWT_SECRET=<secret largo>');
  console.log('  4. EMAIL_CRON_SECRET=<secret para crons>');
  console.log('  5. BREVO_API_KEY (si EMAIL_ENABLED=true)\n');

  if (fs.existsSync(stagingPath)) {
    dotenv.config({ path: stagingPath });
    process.env.ENV_FILE = STAGING_ENV;
    const checks = validateSupabaseEnvFields({
      envPath: stagingPath,
      requireBrevo: process.env.EMAIL_ENABLED === 'true',
    });
    console.log('Estado actual:');
    printEnvChecks(checks);

    if (hasFailedChecks(checks)) {
      console.log('\nSiguiente: editá .env.staging y corré npm run supabase:bootstrap');
      process.exit(1);
    }

    console.log('\n.env.staging listo. Siguiente: npm run supabase:bootstrap -- --apply');
  }
}

main();
