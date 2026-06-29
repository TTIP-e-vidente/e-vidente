/**
 * Preflight antes de deploy o staging: env, DB, migraciones, email, crons.
 *
 * Uso:
 *   npm run check:deploy:staging
 *   ENV_FILE=.env.production npm run check:deploy -- --production
 */
import { execSync } from 'child_process';
import path from 'path';
import {
  BACKEND_ROOT,
  connectSupabase,
  createPoolFromCurrentEnv,
  describeConnection,
  loadBackendEnv,
  validatePoolConnection,
} from './lib/postgres-env';
import { EXPECTED_MIGRATION_COUNT } from './lib/public-tables';
import {
  detectSupabaseHostKind,
  hasFailedChecks,
  printEnvChecks,
  validateSupabaseEnvFields,
} from './lib/supabase-env';
import { emailConfig, isEmailDeliveryConfigured } from '../src/modules/email/email.config';
import { describePoolConfig, isRemotePostgres } from '../src/config/postgresPoolConfig';

async function main(): Promise<void> {
  const production = process.argv.includes('--production');
  const testCron = process.argv.includes('--test-cron');

  const loaded = loadBackendEnv();
  const envPath = path.resolve(BACKEND_ROOT, loaded.envFile);

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Deploy readiness check');
  console.log('═══════════════════════════════════════════');
  console.log(`Env: ${loaded.envFile}`);
  console.log(`Target: ${describeConnection()}\n`);

  const envChecks = validateSupabaseEnvFields({
    envPath,
    requirePublicUrl: production,
    requireBrevo: production && emailConfig.enabled,
    requireEdgeFunctions: production,
  });

  console.log('Variables de entorno:');
  printEnvChecks(envChecks);

  if (hasFailedChecks(envChecks)) {
    process.exit(1);
  }

  if (!isRemotePostgres()) {
    console.error('\nERROR: este check es para Postgres remoto (POSTGRES_SSL=true).');
    process.exit(1);
  }

  const poolConfig = describePoolConfig();
  console.log('\nPool:');
  console.log(`  max=${poolConfig.max} ssl=${poolConfig.ssl} idleMs=${poolConfig.idleTimeoutMillis}`);

  const hostKind = detectSupabaseHostKind(process.env.POSTGRES_HOST);
  if (hostKind === 'direct' && production) {
    console.log('\n  warn: en producción conviene Session pooler (aws-0-….pooler.supabase.com)');
  }

  try {
    await connectSupabase({ envPath, persistToEnvFile: true });
    const pool = createPoolFromCurrentEnv();
    try {
      const info = await validatePoolConnection(pool);
      console.log(`\nDB: OK — ${info.user}@${info.database}`);
      console.log(`  ${describeConnection()}`);

      const migrations = await pool.query<{ count: string }>(
        'SELECT COUNT(*)::text AS count FROM schema_migrations;'
      );
      const count = Number.parseInt(migrations.rows[0]?.count ?? '0', 10);
      const migrationsOk = count >= EXPECTED_MIGRATION_COUNT;
      console.log(
        `Migraciones: ${migrationsOk ? 'OK' : 'FAIL'} — ${count}/${EXPECTED_MIGRATION_COUNT}`
      );
      if (!migrationsOk) {
        console.log('  → npm run setup:supabase o npm run deploy:migrate');
        process.exit(1);
      }
    } finally {
      await pool.end();
    }
  } catch (error) {
    console.error('\nDB: FAIL —', (error as Error).message);
    console.error('Probá: npm run supabase:diagnose');
    process.exit(1);
  }

  console.log('\nEmail:');
  console.log(`  enabled=${emailConfig.enabled} configured=${isEmailDeliveryConfigured()}`);
  if (emailConfig.enabled && !isEmailDeliveryConfigured()) {
    console.log('  warn: EMAIL_ENABLED=true pero Brevo incompleto');
  }

  const publicUrl = process.env.BACKEND_BASE_URL?.trim();
  if (testCron && publicUrl) {
    console.log('\nCron smoke (POST /internal/jobs/outbound-emails):');
    try {
      execSync(
        `npx ts-node scripts/smoke-cron.ts "${publicUrl}" outbound-emails`,
        { cwd: BACKEND_ROOT, stdio: 'inherit' }
      );
    } catch {
      process.exit(1);
    }
  } else if (production && publicUrl) {
    console.log('\nCron: pg_cron en Supabase → Edge internal-job (migración 033)');
    console.log('  Verificar: npm run check:edge (con el mismo ENV_FILE)');
    console.log('  Leaderboard opcional: BACKEND_BASE_URL en secrets Edge + Express');
  }

  if (process.argv.includes('--edge') || production) {
    console.log('\nEdge Functions:');
    try {
      execSync('npx ts-node scripts/check-edge-functions.ts', {
        cwd: BACKEND_ROOT,
        stdio: 'inherit',
        env: process.env,
      });
    } catch {
      if (production) {
        process.exit(1);
      }
      console.log('  warn: Edge Functions no verificadas (deploy pendiente)');
    }
  }

  console.log('\nDeploy readiness OK.');
}

main().catch((error) => {
  console.error('\nDeploy readiness falló:', error);
  process.exit(1);
});
