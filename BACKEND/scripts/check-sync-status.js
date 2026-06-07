const { Pool } = require('pg');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'localhost',
  port: parseInt(process.env.POSTGRES_PORT || '5433'),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

async function run() {
  const client = await pool.connect();
  try {
    const progress = await client.query(`
      SELECT u.username,
             u.avatar_image_id IS NOT NULL AS has_avatar,
             pr.restriction,
             pr.total_exp,
             pr.completed_nodes_count,
             pr.map_completed,
             COUNT(hg.id) AS history_nodes,
             SUM(CASE WHEN hg.completed THEN 1 ELSE 0 END)::int AS completed_nodes
      FROM users u
      JOIN profiles p ON p.user_id = u.id
      JOIN progress_restrictions pr ON pr.profile_id = p.id
      LEFT JOIN history_games hg ON hg.progress_id = pr.id
      GROUP BY u.username, u.avatar_image_id, pr.restriction,
               pr.total_exp, pr.completed_nodes_count, pr.map_completed
      ORDER BY u.username, pr.restriction
    `);
    console.log('\n=== PROGRESO POR USUARIO/RESTRICCION ===');
    progress.rows.forEach(r => console.log(JSON.stringify(r)));

    const images = await client.query(`
      SELECT u.username, i.mime_type, length(i.data) AS bytes, i.updated_at
      FROM images i
      JOIN users u ON u.id = i.user_id
    `);
    console.log('\n=== AVATARES EN DB ===');
    if (images.rows.length === 0) console.log('  (vacío)');
    images.rows.forEach(r => console.log(JSON.stringify(r)));

    const recentGames = await client.query(`
      SELECT u.username, g.node_id, g.score, g.accuracy, g.created_at
      FROM games g
      JOIN history_games hg ON hg.id = g.history_id
      JOIN progress_restrictions pr ON pr.id = hg.progress_id
      JOIN profiles p ON p.id = pr.profile_id
      JOIN users u ON u.id = p.user_id
      ORDER BY g.created_at DESC
      LIMIT 5
    `);
    console.log('\n=== ULTIMAS 5 PARTIDAS EN DB ===');
    recentGames.rows.forEach(r => console.log(JSON.stringify(r)));

  } finally {
    client.release();
    pool.end();
  }
}

run().catch(e => { console.error('ERROR:', e.message); pool.end(); });
