/**
 * Verifica que Supabase staging/prod tenga schema, RLS y datos coherentes.
 *
 * Uso:
 *   npm run verify:supabase
 *   npm run verify:supabase -- --compare-local
 */
import fs from 'fs/promises';
import path from 'path';
import {
  assertLocalDockerEnv,
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  describeConnection,
  loadPostgresEnv,
  validatePoolConnection,
} from './lib/postgres-env';
import {
  countTableRows,
  CRITICAL_PUBLIC_TABLES,
  EXPECTED_MIGRATION_COUNT,
  listPublicTables,
} from './lib/public-tables';
import { isPlaceholderSecret, PLACEHOLDER_JWT_SECRETS } from './lib/supabase-env';

const BACKEND_ROOT = path.resolve(__dirname, '..');
const MIGRATIONS_DIR = path.join(BACKEND_ROOT, 'migrations');

interface CheckResult {
  ok: boolean;
  warn?: boolean;
  message: string;
}

function fail(message: string): CheckResult {
  return { ok: false, message };
}

function pass(message: string): CheckResult {
  return { ok: true, message };
}

function warn(message: string): CheckResult {
  return { ok: true, warn: true, message };
}

async function expectedMigrationFilenames(): Promise<string[]> {
  const files = await fs.readdir(MIGRATIONS_DIR);
  return files.filter((name) => name.endsWith('.sql')).sort();
}

async function main(): Promise<void> {
  const compareLocal = process.argv.includes('--compare-local');

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Verificar Supabase');
  console.log('═══════════════════════════════════════════');

  const staging = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(staging.envPath);

  const checks: CheckResult[] = [];

  try {
    await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true });
  } catch (error) {
    checks.push(fail(`Conexión falló: ${(error as Error).message}`));
    printChecks(checks);
    console.error('\nProbá: npm run supabase:diagnose');
    process.exit(1);
  }

  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });

  try {
    const info = await validatePoolConnection(pool);
    checks.push(pass(`Conexión OK (${describeConnection()}) — user: ${info.user}`));

  const extensionResult = await pool.query<{ extname: string }>(
    `SELECT extname FROM pg_extension WHERE extname IN ('pgcrypto', 'pg_cron', 'pg_net');`
  );
  const installedExtensions = new Set(extensionResult.rows.map((row) => row.extname));
  checks.push(
    installedExtensions.has('pgcrypto')
      ? pass('Extensión pgcrypto instalada')
      : fail('Falta extensión pgcrypto')
  );
  checks.push(
    installedExtensions.has('pg_cron')
      ? pass('Extensión pg_cron instalada (jobs Supabase)')
      : fail('Falta extensión pg_cron — corré npm run setup:supabase')
  );
  checks.push(
    installedExtensions.has('pg_net')
      ? pass('Extensión pg_net instalada (HTTP desde cron)')
      : fail('Falta extensión pg_net — corré npm run setup:supabase')
  );

  try {
    const cronJobs = await pool.query<{ jobname: string }>(
      `SELECT jobname FROM cron.job WHERE jobname LIKE 'evidente-%' ORDER BY jobname;`
    );
    const cronJobCount = cronJobs.rowCount ?? 0;
    checks.push(
      cronJobCount >= 4
        ? pass(`Jobs pg_cron evidente: ${cronJobCount} (${cronJobs.rows.map((r) => r.jobname).join(', ')})`)
        : fail(
            `Jobs pg_cron incompletos: ${cronJobCount}/4 — corré npm run setup:supabase:cron`
          )
    );

    const cronSettings = await pool.query<{ key: string }>(
      `SELECT key FROM private.internal_cron_settings WHERE key IN ('backend_base_url', 'email_cron_secret');`
    );
    const settingKeys = new Set(cronSettings.rows.map((row) => row.key));
    checks.push(
      settingKeys.has('backend_base_url') && settingKeys.has('email_cron_secret')
        ? pass('Config cron en Supabase (URL + secret)')
        : fail('Faltan settings cron — npm run setup:supabase:cron')
    );

    const baseUrlRow = await pool.query<{ value: string }>(
      `SELECT value FROM private.internal_cron_settings WHERE key = 'backend_base_url';`
    );
    const baseUrl = baseUrlRow.rows[0]?.value ?? '';
    if (/localhost|127\.0\.0\.1/i.test(baseUrl)) {
      checks.push(
        warn(
          `BACKEND_BASE_URL es local (${baseUrl}) — crons Supabase omiten envío; dev usa npm run dev`
        )
      );
    } else if (baseUrl.length > 0) {
      checks.push(pass(`BACKEND_BASE_URL cron: ${baseUrl}`));
    }

    try {
      const lastRun = await pool.query<{ jobname: string; status: string; start_time: Date }>(
        `
          SELECT j.jobname, d.status, d.start_time
          FROM cron.job_run_details d
          INNER JOIN cron.job j ON j.jobid = d.jobid
          WHERE j.jobname LIKE 'evidente-%'
          ORDER BY d.start_time DESC
          LIMIT 1;
        `
      );
      const row = lastRun.rows[0];
      if (row) {
        checks.push(
          pass(`Último pg_cron: ${row.jobname} ${row.status} @ ${row.start_time.toISOString()}`)
        );
      } else if (!/localhost|127\.0\.0\.1/i.test(baseUrl)) {
        checks.push(warn('Aún no hay ejecuciones pg_cron registradas (normal tras el setup)'));
      }
    } catch {
      checks.push(warn('cron.job_run_details no disponible'));
    }
  } catch (error) {
    checks.push(
      fail(
        `Cron Supabase no verificado (¿migración 031?): ${error instanceof Error ? error.message : String(error)}`
      )
    );
  }

  const expectedFiles = await expectedMigrationFilenames();
  const appliedResult = await pool.query<{ filename: string }>(
    'SELECT filename FROM schema_migrations ORDER BY filename;'
  );
  const applied = new Set(appliedResult.rows.map((row) => row.filename));

  checks.push(
    applied.size >= EXPECTED_MIGRATION_COUNT
      ? pass(`Migraciones aplicadas: ${applied.size}/${expectedFiles.length}`)
      : fail(`Migraciones incompletas: ${applied.size}/${expectedFiles.length}`)
  );

  const missingMigrations = expectedFiles.filter((filename) => !applied.has(filename));
  if (missingMigrations.length > 0) {
    checks.push(fail(`Faltan migraciones: ${missingMigrations.join(', ')}`));
  } else {
    checks.push(pass('Todas las migraciones del repo están registradas'));
  }

  const lastExpected = expectedFiles[expectedFiles.length - 1];
  if (lastExpected && applied.has(lastExpected)) {
    checks.push(pass(`Última migración presente: ${lastExpected}`));
  } else {
    checks.push(fail(`Falta última migración esperada: ${lastExpected}`));
  }

  for (const table of CRITICAL_PUBLIC_TABLES) {
    const exists = await pool.query<{ regclass: string | null }>(
      `SELECT to_regclass($1) AS regclass;`,
      [`public.${table}`]
    );
    checks.push(
      exists.rows[0]?.regclass
        ? pass(`Tabla crítica existe: ${table}`)
        : fail(`Falta tabla crítica: ${table}`)
    );
  }

  const rlsResult = await pool.query<{ tablename: string; rowsecurity: boolean }>(
    `
      SELECT c.relname AS tablename, c.relrowsecurity AS rowsecurity
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relkind = 'r'
        AND c.relname <> 'schema_migrations'
      ORDER BY c.relname;
    `
  );

  const tablesWithoutRls = rlsResult.rows.filter((row) => !row.rowsecurity).map((row) => row.tablename);
  checks.push(
    tablesWithoutRls.length === 0
      ? pass(`RLS activo en ${rlsResult.rowCount} tablas public`)
      : fail(`RLS desactivado en: ${tablesWithoutRls.join(', ')}`)
  );

  const jwtSecret = process.env.JWT_SECRET?.trim() ?? '';
  if (!jwtSecret) {
    checks.push(fail('JWT_SECRET vacío en .env.staging'));
  } else if (isPlaceholderSecret(jwtSecret, PLACEHOLDER_JWT_SECRETS)) {
    checks.push(fail('JWT_SECRET sigue siendo el placeholder de ejemplo'));
  } else {
    checks.push(pass('JWT_SECRET configurado'));
  }

  const client = await pool.connect();
  try {
    const publicTables = await listPublicTables(client);

    console.log('\nFilas por tabla:');
    const rowCounts = new Map<string, number>();
    for (const table of publicTables) {
      const count = await countTableRows(client, table);
      rowCounts.set(table, count);
      console.log(`  ${table}: ${count}`);
    }

    if (compareLocal) {
      console.log('\nComparación con local:');
      loadPostgresEnv('local');
      assertLocalDockerEnv();
      const localPool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 5000 });
      const localClient = await localPool.connect();
      try {
        const localTables = await listPublicTables(localClient);
        const allTables = new Set([...publicTables, ...localTables]);
        let mismatches = 0;

        for (const table of [...allTables].sort()) {
          const remoteCount = rowCounts.get(table) ?? 0;
          const localCount = localTables.includes(table)
            ? await countTableRows(localClient, table)
            : 0;

          if (remoteCount !== localCount) {
            mismatches += 1;
            console.log(`  mismatch ${table}: local=${localCount} remote=${remoteCount}`);
          }
        }

        checks.push(
          mismatches === 0
            ? pass('Conteo de filas coincide con local')
            : fail(`${mismatches} tabla(s) con conteo distinto al local`)
        );
      } finally {
        localClient.release();
        await localPool.end();
      }

      loadPostgresEnv('staging');
    }
  } finally {
    client.release();
  }

  printChecks(checks);
  const failed = checks.filter((check) => !check.ok);
  if (failed.length > 0) {
    process.exit(1);
  }

  console.log('\nVerificación Supabase OK.');
  } finally {
    await pool.end();
  }
}

function printChecks(checks: CheckResult[]): void {
  console.log('\nChecks:');
  for (const check of checks) {
    const label = check.ok ? (check.warn ? 'WARN' : 'OK') : 'FAIL';
    console.log(`  ${label} — ${check.message}`);
  }
}

main().catch((error) => {
  console.error('\nVerificación Supabase falló:', error);
  process.exit(1);
});
