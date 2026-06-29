/**
 * Lista usuarios en Supabase Postgres (sin Express).
 * Uso: npm run query:users:staging
 */
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
} from './lib/postgres-env';

async function main(): Promise<void> {
  const staging = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(staging.envPath);
  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true, silent: true });

  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  const client = await pool.connect();
  try {
    const result = await client.query<{
      username: string;
      mail: string | null;
      mail_verified_at: Date | null;
      created_at: Date;
    }>(
      `
        SELECT username, mail, mail_verified_at, created_at
        FROM users
        ORDER BY username;
      `,
    );

    console.log('═══════════════════════════════════════════');
    console.log('  Usuarios en Supabase (directo Postgres)');
    console.log('═══════════════════════════════════════════\n');

    if (result.rows.length === 0) {
      console.log('  (sin usuarios)');
      return;
    }

    for (const row of result.rows) {
      const verified = row.mail_verified_at ? '✓ verificado' : '○ sin verificar';
      console.log(`  • ${row.username}`);
      console.log(`    mail: ${row.mail ?? '(sin mail)'} — ${verified}`);
    }
    console.log(`\nTotal: ${result.rows.length}`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error('\nquery:users falló:', error);
  process.exit(1);
});
