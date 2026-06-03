import fs from 'fs/promises';
import path from 'path';
import { pool } from '../src/config/database';

async function ensureMigrationTable(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT UNIQUE NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

async function getAppliedMigrations(): Promise<Set<string>> {
  const result = await pool.query<{ filename: string }>(
    'SELECT filename FROM schema_migrations ORDER BY filename;'
  );

  return new Set(result.rows.map((row) => row.filename));
}

async function run(): Promise<void> {
  const migrationsDirectory = path.resolve(process.cwd(), 'migrations');
  await ensureMigrationTable();

  const appliedMigrations = await getAppliedMigrations();
  const migrationFiles = (await fs.readdir(migrationsDirectory))
    .filter((filename) => filename.endsWith('.sql'))
    .sort();

  for (const filename of migrationFiles) {
    if (appliedMigrations.has(filename)) {
      console.log(`skip ${filename}`);
      continue;
    }

    const client = await pool.connect();
    try {
      const sql = await fs.readFile(path.join(migrationsDirectory, filename), 'utf8');
      console.log(`apply ${filename}`);
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (filename) VALUES ($1);', [filename]);
      await client.query('COMMIT');
      console.log(`done ${filename}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}

run()
  .then(async () => {
    await pool.end();
  })
  .catch(async (error) => {
    console.error('migration failed');
    console.error(error);
    await pool.end();
    process.exit(1);
  });
