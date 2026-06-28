/**
 * Copia datos del Postgres local (Docker) a Supabase staging.
 * Requisitos: schema ya migrado en remoto (npm run setup:supabase).
 *
 * Uso:
 *   npx ts-node scripts/migrate-data-local-to-supabase.ts --dry-run
 *   npx ts-node scripts/migrate-data-local-to-supabase.ts --apply
 */
import { Pool, PoolClient } from 'pg';
import {
  assertLocalDockerEnv,
  assertSupabaseStagingEnv,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
  validatePoolConnection,
} from './lib/postgres-env';

const EXCLUDED_TABLES = new Set(['schema_migrations']);

async function listPublicTables(client: PoolClient): Promise<string[]> {
  const result = await client.query<{ tablename: string }>(
    `
      SELECT tablename
      FROM pg_tables
      WHERE schemaname = 'public'
      ORDER BY tablename;
    `
  );
  return result.rows.map((row) => row.tablename).filter((name) => !EXCLUDED_TABLES.has(name));
}

async function countRows(client: PoolClient, table: string): Promise<number> {
  const result = await client.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM public.${quoteIdent(table)};`
  );
  return Number.parseInt(result.rows[0]?.count ?? '0', 10);
}

function quoteIdent(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

async function copyTable(
  local: PoolClient,
  remote: PoolClient,
  table: string,
  apply: boolean
): Promise<number> {
  const selectResult = await local.query(`SELECT * FROM public.${quoteIdent(table)};`);
  const rows = selectResult.rows as Record<string, unknown>[];
  if (rows.length === 0) {
    return 0;
  }

  if (!apply) {
    return rows.length;
  }

  const columns = Object.keys(rows[0]);
  const columnList = columns.map(quoteIdent).join(', ');
  const placeholders = columns.map((_, index) => `$${index + 1}`).join(', ');

  await remote.query(`TRUNCATE public.${quoteIdent(table)} CASCADE;`);

  for (const row of rows) {
    const values = columns.map((column) => row[column]);
    await remote.query(
      `INSERT INTO public.${quoteIdent(table)} (${columnList}) VALUES (${placeholders});`,
      values
    );
  }

  return rows.length;
}

async function main(): Promise<void> {
  const apply = process.argv.includes('--apply');
  const dryRun = process.argv.includes('--dry-run') || !apply;

  if (apply && dryRun) {
    console.error('Usá solo uno: --dry-run o --apply');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Datos local → Supabase');
  console.log('═══════════════════════════════════════════');

  const localEnv = loadPostgresEnv('local');
  assertLocalDockerEnv();

  const localPool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 5000 });
  let localInfo: { database: string; user: string };
  try {
    localInfo = await validatePoolConnection(localPool);
    console.log(`\nOrigen (local): ${localInfo.user}@${localInfo.database}`);
  } catch (error) {
    console.error('\nERROR: no se conecta al Postgres local.');
    console.error('Corré: npm run setup:dev');
    console.error((error as Error).message);
    process.exit(1);
  }

  const stagingEnv = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(stagingEnv.envPath);

  const remotePool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 10000 });
  let remoteInfo: { database: string; user: string };
  try {
    remoteInfo = await validatePoolConnection(remotePool);
    console.log(`Destino (Supabase): ${remoteInfo.user}@${remoteInfo.database}`);
  } catch (error) {
    console.error('\nERROR: no se conecta a Supabase.');
    console.error('Revisá BACKEND/.env.staging');
    console.error((error as Error).message);
    process.exit(1);
  }

  const localClient = await localPool.connect();
  const remoteClient = await remotePool.connect();

  try {
    const tables = await listPublicTables(localClient);
    console.log(`\nTablas a copiar: ${tables.length} (sin schema_migrations)`);
    console.log(dryRun ? '\nModo: DRY-RUN (sin escribir en Supabase)\n' : '\nModo: APPLY (trunca y copia)\n');

    let totalRows = 0;
    for (const table of tables) {
      const localCount = await countRows(localClient, table);
      if (localCount === 0) {
        console.log(`  skip ${table} (0 filas)`);
        continue;
      }

      if (dryRun) {
        console.log(`  copy ${table}: ${localCount} filas`);
        totalRows += localCount;
        continue;
      }

      const copied = await copyTable(localClient, remoteClient, table, true);
      console.log(`  done ${table}: ${copied} filas`);
      totalRows += copied;
    }

    if (dryRun) {
      console.log(`\nDRY-RUN OK — se copiarían ${totalRows} filas en total.`);
      console.log('Para aplicar: npx ts-node scripts/migrate-data-local-to-supabase.ts --apply');
    } else {
      console.log(`\nCopiadas ${totalRows} filas.`);
      console.log('Opcional: npm run smoke:api:staging');
    }
  } finally {
    localClient.release();
    remoteClient.release();
    await localPool.end();
    await remotePool.end();
  }
}

main().catch((error) => {
  console.error('\nMigración de datos falló:', error);
  process.exit(1);
});
