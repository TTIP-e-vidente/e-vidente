/**
 * Repara usuarios con código OTP usado pero mail_verified_at NULL (bug histórico).
 *
 * Uso:
 *   npm run repair:mail-verification:staging
 *   npm run repair:mail-verification:staging -- --apply
 */
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  loadPostgresEnv,
} from './lib/postgres-env';

interface RepairCandidate {
  user_id: string;
  username: string;
  mail: string;
  used_at: Date;
}

async function findCandidates(client: import('pg').PoolClient): Promise<RepairCandidate[]> {
  const result = await client.query<RepairCandidate>(
    `
      SELECT DISTINCT ON (u.id)
        u.id AS user_id,
        u.username,
        u.mail,
        evc.used_at
      FROM users u
      INNER JOIN email_verification_codes evc
        ON evc.user_id = u.id
       AND evc.used_at IS NOT NULL
      WHERE u.mail_verified_at IS NULL
        AND u.mail IS NOT NULL
        AND lower(trim(u.mail)) = lower(trim(evc.target_mail))
      ORDER BY u.id, evc.used_at DESC;
    `
  );
  return result.rows;
}

async function main(): Promise<void> {
  const apply = process.argv.includes('--apply');
  const staging = loadPostgresEnv('staging');
  assertSupabaseStagingEnv(staging.envPath);

  await connectSupabase({ envPath: staging.envPath, persistToEnvFile: true });
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 15000 });
  const client = await pool.connect();

  try {
    const candidates = await findCandidates(client);

    console.log('═══════════════════════════════════════════');
    console.log('  Reparar verificación de mail');
    console.log('═══════════════════════════════════════════\n');

    if (candidates.length === 0) {
      console.log('Nada que reparar — no hay cuentas con OTP usado y mail sin verificar.');
      return;
    }

    for (const row of candidates) {
      console.log(
        `  • ${row.username} (${row.mail}) — OTP usado ${row.used_at.toISOString()}`
      );
    }

    if (!apply) {
      console.log(`\nPreview: ${candidates.length} cuenta(s). Para aplicar: --apply`);
      return;
    }

    const updated = await client.query<{ id: string }>(
      `
        UPDATE users u
        SET mail_verified_at = sub.used_at, updated_at = now()
        FROM (
          SELECT DISTINCT ON (evc.user_id)
            evc.user_id,
            evc.used_at
          FROM email_verification_codes evc
          INNER JOIN users u2 ON u2.id = evc.user_id
          WHERE evc.used_at IS NOT NULL
            AND u2.mail_verified_at IS NULL
            AND u2.mail IS NOT NULL
            AND lower(trim(u2.mail)) = lower(trim(evc.target_mail))
          ORDER BY evc.user_id, evc.used_at DESC
        ) sub
        WHERE u.id = sub.user_id
        RETURNING u.id;
      `
    );

    console.log(`\nReparadas ${updated.rowCount ?? 0} cuenta(s).`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error('\nReparación falló:', error);
  process.exit(1);
});
