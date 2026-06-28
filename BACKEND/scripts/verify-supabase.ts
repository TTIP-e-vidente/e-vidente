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
  message: string;
}

function fail(message: string): CheckResult {
  return { ok: false, message };
}

function pass(message: string): CheckResult {
  return { ok: true, message };
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
    `SELECT extname FROM pg_extension WHERE extname = 'pgcrypto';`
  );
  checks.push(
    extensionResult.rowCount
      ? pass('Extensión pgcrypto instalada')
      : fail('Falta extensión pgcrypto')
  );

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
    console.log(`  ${check.ok ? 'OK' : 'FAIL'} — ${check.message}`);
  }
}

main().catch((error) => {
  console.error('\nVerificación Supabase falló:', error);
  process.exit(1);
});
