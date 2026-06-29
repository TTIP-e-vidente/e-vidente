import pg from 'pg';
const { Pool } = pg;

const pool = new Pool({
  host: 'aws-1-us-east-1.pooler.supabase.com',
  port: 5432,
  database: 'postgres',
  user: 'postgres.kpvjdzdynqfhqfiatwqz',
  password: 'evidente2026#?',
  ssl: { rejectUnauthorized: false }
});

// Prefijos de usuarios de smoke/integration tests
const SMOKE_PATTERNS = [
  'edge_%',
  'smoke_%',
  'test_%',
  'verify_smoke_%',
];

const whereClause = SMOKE_PATTERNS.map((_, i) => `username LIKE $${i + 1}`).join(' OR ');

const preview = await pool.query(
  `SELECT id, username, name, created_at FROM users WHERE ${whereClause} ORDER BY created_at`,
  SMOKE_PATTERNS
);

console.log(`\n=== USUARIOS A ELIMINAR (${preview.rows.length}) ===`);
preview.rows.forEach(u => console.log(`  - ${u.username} (${u.name}) [${u.created_at.toISOString()}]`));

const realUsersResult = await pool.query(
  `SELECT id, username, name, created_at FROM users WHERE NOT (${whereClause}) ORDER BY created_at`,
  SMOKE_PATTERNS
);
console.log(`\n=== USUARIOS REALES A CONSERVAR (${realUsersResult.rows.length}) ===`);
realUsersResult.rows.forEach(u => console.log(`  + ${u.username} (${u.name}) [${u.created_at.toISOString()}]`));

if (preview.rows.length === 0) {
  console.log('\nNo hay usuarios de smoke para eliminar.');
  await pool.end();
  process.exit(0);
}

console.log('\n=== EJECUTANDO DELETE... ===');
const del = await pool.query(
  `DELETE FROM users WHERE ${whereClause} RETURNING username`,
  SMOKE_PATTERNS
);
console.log(`Eliminados: ${del.rowCount} usuarios de smoke/test.`);

// Forzar refresh del leaderboard invalidando el snapshot
console.log('\n=== LIMPIANDO SNAPSHOTS VIEJOS DEL LEADERBOARD... ===');
const snapDel = await pool.query(
  `DELETE FROM leaderboard_snapshots RETURNING scope`
);
console.log(`Snapshots eliminados: ${snapDel.rowCount} (se regeneran en el próximo cron)`);

await pool.end();
console.log('\n✅ Listo. El leaderboard se regenerará en el próximo refresh automático.');
