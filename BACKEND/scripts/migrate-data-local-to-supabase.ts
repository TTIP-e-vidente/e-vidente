/**
 * Copia datos del Postgres local (Docker) a Supabase staging.
 * Requisitos: schema ya migrado en remoto (npm run setup:supabase).
 *
 * Uso:
 *   npx ts-node scripts/migrate-data-local-to-supabase.ts --dry-run
 *   npx ts-node scripts/migrate-data-local-to-supabase.ts --apply
 */
import { PoolClient } from 'pg';
import {
  assertLocalDockerEnv,
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
  validatePoolConnection,
} from './lib/postgres-env';
import {
  countTableRows,
  listPublicTables,
  quoteIdent,
  sortPublicTablesByForeignKeys,
  truncatePublicTables,
} from './lib/public-tables';

const INSERT_BATCH_SIZE = 200;

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

  for (let offset = 0; offset < rows.length; offset += INSERT_BATCH_SIZE) {
    const batch = rows.slice(offset, offset + INSERT_BATCH_SIZE);
    const valueGroups: string[] = [];
    const values: unknown[] = [];

    batch.forEach((row, rowIndex) => {
      const placeholders = columns.map((_, columnIndex) => {
        values.push(row[columns[columnIndex]]);
        return `$${rowIndex * columns.length + columnIndex + 1}`;
      });
      valueGroups.push(`(${placeholders.join(', ')})`);
    });

    await remote.query(
      `INSERT INTO public.${quoteIdent(table)} (${columnList}) VALUES ${valueGroups.join(', ')};`,
      values
    );
  }

  return rows.length;
}

async function main(): Promise<void> {
  const apply = process.argv.includes('--apply');
  const dryRun = process.argv.includes('--dry-run') || !apply;

  if (apply && process.argv.includes('--dry-run')) {
    console.error('Usá solo uno: --dry-run o --apply');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Datos local → Supabase');
  console.log('═══════════════════════════════════════════');

  loadPostgresEnv('local');
  assertLocalDockerEnv();

  const localPool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 5000 });
  try {
    const localInfo = await validatePoolConnection(localPool);
    console.log(`\nOrigen (local): ${localInfo.user}@${localInfo.database}`);
  } catch (error) {
    console.error('\nERROR: no se conecta al Postgres local.');
    console.error('Corré: npm run setup:dev');
    console.error((error as Error).message);
    process.exit(1);
  }

  const stagingEnv = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(stagingEnv.envPath);

  await connectSupabase({ envPath: stagingEnv.envPath, persistToEnvFile: true });

  const remotePool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 10000 });
  try {
    const remoteInfo = await validatePoolConnection(remotePool);
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
    const orderedTables = await sortPublicTablesByForeignKeys(localClient, tables);

    console.log(`\nTablas a copiar: ${orderedTables.length} (sin schema_migrations)`);
    console.log(`Orden: ${orderedTables.join(' → ')}`);
    console.log(dryRun ? '\nModo: DRY-RUN (sin escribir en Supabase)\n' : '\nModo: APPLY (trunca y copia)\n');

    const tablesWithRows: string[] = [];
    for (const table of orderedTables) {
      const localCount = await countTableRows(localClient, table);
      if (localCount === 0) {
        console.log(`  skip ${table} (0 filas)`);
        continue;
      }
      tablesWithRows.push(table);
      if (dryRun) {
        console.log(`  copy ${table}: ${localCount} filas`);
      }
    }

    if (!dryRun && tablesWithRows.length > 0) {
      console.log('\nTruncando tablas destino (CASCADE)…');
      await truncatePublicTables(remoteClient, tablesWithRows);
    }

    let totalRows = 0;
    if (!dryRun) {
      await remoteClient.query('SET session_replication_role = replica');
      try {
        for (const table of tablesWithRows) {
          const copied = await copyTable(localClient, remoteClient, table, true);
          console.log(`  done ${table}: ${copied} filas`);
          totalRows += copied;
        }
      } finally {
        await remoteClient.query('SET session_replication_role = DEFAULT');
      }
    } else {
      for (const table of tablesWithRows) {
        totalRows += await countTableRows(localClient, table);
      }
    }

    if (dryRun) {
      console.log(`\nDRY-RUN OK — se copiarían ${totalRows} filas en total.`);
      console.log('Para aplicar: npm run migrate:data-to-supabase');
    } else {
      console.log(`\nCopiadas ${totalRows} filas.`);
      console.log('Siguiente: npm run verify:supabase');
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
