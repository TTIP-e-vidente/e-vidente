import { Pool } from 'pg';
import * as fs from 'fs';

const pool = new Pool({
  host: 'localhost',
  database: 'evidente_dev',
  user: 'evidente_user',
  password: 'evidente_password',
  port: 5432,
});

async function run() {
  const tablesResult = await pool.query(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name;
  `);

  const columnsResult = await pool.query(`
    SELECT table_name, column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
    ORDER BY table_name, ordinal_position;
  `);

  const constraintsResult = await pool.query(`
    SELECT
        tc.table_name, 
        kcu.column_name, 
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name,
        tc.constraint_type
    FROM 
        information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
    WHERE tc.table_schema = 'public' AND tc.constraint_type IN ('FOREIGN KEY', 'PRIMARY KEY');
  `);

  const data = {
    tables: tablesResult.rows,
    columns: columnsResult.rows,
    constraints: constraintsResult.rows
  };

  fs.writeFileSync('schema_dump.json', JSON.stringify(data, null, 2));
  console.log('Schema dumped to schema_dump.json');
  await pool.end();
}

run().catch(console.error);
