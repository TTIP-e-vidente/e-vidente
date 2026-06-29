import type { PoolClient } from 'pg';
import { EXPECTED_MIGRATION_COUNT } from '../../src/config/migrations-meta';

export { EXPECTED_MIGRATION_COUNT };

/** Tablas que no se copian entre entornos (control de migraciones propio). */
export const EXCLUDED_PUBLIC_TABLES = new Set(['schema_migrations']);

export const CRITICAL_PUBLIC_TABLES = [
  'users',
  'images',
  'profiles',
  'streaks',
  'progress_restrictions',
  'history_games',
  'games',
  'email_verification_codes',
  'email_deliveries',
  'leaderboard_snapshots',
] as const;

export function quoteIdent(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

export async function listPublicTables(
  client: PoolClient,
  excluded: ReadonlySet<string> = EXCLUDED_PUBLIC_TABLES
): Promise<string[]> {
  const result = await client.query<{ tablename: string }>(
    `
      SELECT tablename
      FROM pg_tables
      WHERE schemaname = 'public'
      ORDER BY tablename;
    `
  );
  return result.rows.map((row) => row.tablename).filter((name) => !excluded.has(name));
}

interface ForeignKeyEdge {
  childTable: string;
  parentTable: string;
}

export async function listForeignKeyEdges(client: PoolClient): Promise<ForeignKeyEdge[]> {
  const result = await client.query<{ child_table: string; parent_table: string }>(
    `
      SELECT
        child_rel.relname AS child_table,
        parent_rel.relname AS parent_table
      FROM pg_constraint constraint_def
      JOIN pg_namespace schema_ns ON schema_ns.oid = constraint_def.connamespace
      JOIN pg_class child_rel ON child_rel.oid = constraint_def.conrelid
      JOIN pg_class parent_rel ON parent_rel.oid = constraint_def.confrelid
      WHERE constraint_def.contype = 'f'
        AND schema_ns.nspname = 'public';
    `
  );

  return result.rows.map((row) => ({
    childTable: row.child_table,
    parentTable: row.parent_table,
  }));
}

/**
 * Orden de inserción: tablas referenciadas antes que las que dependen de ellas.
 * Si hay ciclos (no debería), las tablas del ciclo se agregan al final en orden estable.
 */
export function sortTablesByForeignKeys(tables: string[], edges: ForeignKeyEdge[]): string[] {
  const tableSet = new Set(tables);
  const relevantEdges = edges.filter(
    (edge) => tableSet.has(edge.childTable) && tableSet.has(edge.parentTable)
  );

  const inDegree = new Map<string, number>();
  const childrenByParent = new Map<string, string[]>();

  for (const table of tables) {
    inDegree.set(table, 0);
  }

  for (const edge of relevantEdges) {
    inDegree.set(edge.childTable, (inDegree.get(edge.childTable) ?? 0) + 1);
    const siblings = childrenByParent.get(edge.parentTable) ?? [];
    siblings.push(edge.childTable);
    childrenByParent.set(edge.parentTable, siblings);
  }

  const queue = tables.filter((table) => (inDegree.get(table) ?? 0) === 0);
  const sorted: string[] = [];

  while (queue.length > 0) {
    const current = queue.shift()!;
    sorted.push(current);

    for (const child of childrenByParent.get(current) ?? []) {
      const nextDegree = (inDegree.get(child) ?? 0) - 1;
      inDegree.set(child, nextDegree);
      if (nextDegree === 0) {
        queue.push(child);
      }
    }
  }

  if (sorted.length < tables.length) {
    const remaining = tables.filter((table) => !sorted.includes(table)).sort();
    console.warn(
      `  warn: ciclo o FK cruzada detectada; tablas restantes al final: ${remaining.join(', ')}`
    );
    sorted.push(...remaining);
  }

  return sorted;
}

/** Orden preferido para copia de datos (padres antes que hijos cuando hay ciclos FK). */
export const DATA_MIGRATION_TABLE_ORDER = [
  'leaderboard_meta',
  'restriction_node_config',
  'streaks',
  'users',
  'images',
  'profiles',
  'progress_restrictions',
  'history_games',
  'games',
  'email_verification_codes',
  'email_deliveries',
  'leaderboard_snapshots',
] as const;

export function orderTablesForDataMigration(
  tables: string[],
  topoSorted: string[]
): string[] {
  const tableSet = new Set(tables);
  const preferred = DATA_MIGRATION_TABLE_ORDER.filter((table) => tableSet.has(table));
  const remainder = topoSorted.filter(
    (table) => tableSet.has(table) && !preferred.includes(table as (typeof DATA_MIGRATION_TABLE_ORDER)[number])
  );
  return [...preferred, ...remainder];
}

export async function sortPublicTablesByForeignKeys(
  client: PoolClient,
  tables: string[]
): Promise<string[]> {
  const edges = await listForeignKeyEdges(client);
  const topoSorted = sortTablesByForeignKeys(tables, edges);
  return orderTablesForDataMigration(tables, topoSorted);
}

export async function countTableRows(client: PoolClient, table: string): Promise<number> {
  const result = await client.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM public.${quoteIdent(table)};`
  );
  return Number.parseInt(result.rows[0]?.count ?? '0', 10);
}

export async function truncatePublicTables(
  client: PoolClient,
  tables: string[]
): Promise<void> {
  if (tables.length === 0) {
    return;
  }

  const qualified = tables.map((table) => `public.${quoteIdent(table)}`).join(', ');
  await client.query(`TRUNCATE ${qualified} RESTART IDENTITY CASCADE;`);
}
