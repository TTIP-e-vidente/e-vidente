/**
 * Auditoría rápida: usuarios y progreso en Supabase staging.
 * Uso: npx ts-node scripts/with-env-file.ts .env.staging npx ts-node scripts/staging-data-audit.ts
 */
import { pool } from '../src/config/database';

async function main(): Promise<void> {
  const users = await pool.query<{ username: string; name: string; has_profile: boolean; games: string }>(
    `
      SELECT
        u.username,
        u.name,
        EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = u.id) AS has_profile,
        (SELECT COUNT(*)::text FROM games g WHERE g.user_id = u.id) AS games
      FROM users u
      ORDER BY u.username;
    `
  );

  console.log('═══════════════════════════════════════════');
  console.log('  Usuarios en Supabase (staging)');
  console.log('═══════════════════════════════════════════\n');

  for (const row of users.rows) {
    console.log(
      `  ${row.username} (${row.name}) — perfil=${row.has_profile ? 'sí' : 'no'}, partidas=${row.games}`
    );
  }

  const totals = await pool.query<{ label: string; count: string }>(
    `
      SELECT 'users' AS label, COUNT(*)::text AS count FROM users
      UNION ALL SELECT 'profiles', COUNT(*)::text FROM profiles
      UNION ALL SELECT 'games', COUNT(*)::text FROM games
      UNION ALL SELECT 'history_games', COUNT(*)::text FROM history_games
      UNION ALL SELECT 'progress_restrictions', COUNT(*)::text FROM progress_restrictions;
    `
  );

  console.log('\nTotales:');
  for (const row of totals.rows) {
    console.log(`  ${row.label}: ${row.count}`);
  }
}

main()
  .then(async () => {
    await pool.end();
  })
  .catch(async (error) => {
    console.error(error);
    await pool.end();
    process.exit(1);
  });
