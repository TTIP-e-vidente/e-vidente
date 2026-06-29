/**
 * Limpieza de Supabase staging:
 * - Borra usuarios de prueba (conserva margo/agus).
 * - --reset-data: borra partidas, progreso, rachas, mails transaccionales y leaderboard.
 *
 * Uso:
 *   npm run staging:cleanup
 *   npm run staging:cleanup:apply
 *   npm run staging:reset
 *   npm run staging:reset:apply
 */
import { pool } from '../src/config/database';

const KEEP_USERNAMES = ['margo', 'agus'] as const;

const TEST_USERNAME_PATTERNS: RegExp[] = [
  /^auth_user_/,
  /^player_auth_/,
  /^smoke_user_/,
  /^internal_email_/,
  /^verify_smoke_/,
  /^email_job_/,
  /^mail_flow_/,
  /^integration_player_/,
  /^email_flow_validate$/,
  /^email_flow_lost_validate$/,
];

interface UserRow {
  id: string;
  username: string;
  mail: string | null;
}

interface CountRow {
  label: string;
  count: string;
}

function parseArgs(): { apply: boolean; resetData: boolean; freeMail: string } {
  const apply = process.argv.includes('--apply');
  const resetData = process.argv.includes('--reset-data');
  let freeMail = '';
  for (const arg of process.argv) {
    if (arg.startsWith('--free-mail=')) {
      freeMail = arg.slice('--free-mail='.length).trim().toLowerCase();
    }
  }
  return { apply, resetData, freeMail };
}

function isTestUsername(username: string): boolean {
  return TEST_USERNAME_PATTERNS.some((pattern) => pattern.test(username));
}

function shouldDeleteUser(user: UserRow, freeMail: string): string | null {
  if (KEEP_USERNAMES.includes(user.username as (typeof KEEP_USERNAMES)[number])) {
    return null;
  }
  if (isTestUsername(user.username)) {
    return 'usuario de prueba';
  }
  const mail = (user.mail ?? '').trim().toLowerCase();
  if (freeMail && mail === freeMail) {
    return `mail duplicado (${freeMail})`;
  }
  return 'fuera de la lista conservada';
}

async function listUsers(): Promise<UserRow[]> {
  const result = await pool.query<UserRow>(
    `SELECT id, username, mail FROM users ORDER BY username;`
  );
  return result.rows;
}

async function tableExists(table: string): Promise<boolean> {
  const result = await pool.query<{ exists: boolean }>(
    `
      SELECT EXISTS (
        SELECT 1
        FROM pg_tables
        WHERE schemaname = 'public' AND tablename = $1
      ) AS exists;
    `,
    [table]
  );
  return Boolean(result.rows[0]?.exists);
}

async function countGameplayRows(): Promise<CountRow[]> {
  const parts = [
    `SELECT 'users' AS label, COUNT(*)::text AS count FROM users`,
    `SELECT 'profiles', COUNT(*)::text FROM profiles`,
    `SELECT 'streaks', COUNT(*)::text FROM streaks`,
    `SELECT 'progress_restrictions', COUNT(*)::text FROM progress_restrictions`,
    `SELECT 'history_games', COUNT(*)::text FROM history_games`,
    `SELECT 'games', COUNT(*)::text FROM games`,
    `SELECT 'email_deliveries', COUNT(*)::text FROM email_deliveries`,
    `SELECT 'email_verification_codes', COUNT(*)::text FROM email_verification_codes`,
    `SELECT 'leaderboard_snapshots', COUNT(*)::text FROM leaderboard_snapshots`,
  ];
  if (await tableExists('password_reset_tokens')) {
    parts.push(`SELECT 'password_reset_tokens', COUNT(*)::text FROM password_reset_tokens`);
  }
  const result = await pool.query<CountRow>(parts.join('\nUNION ALL\n'));
  return result.rows;
}

function printCounts(title: string, rows: CountRow[]): void {
  console.log(title);
  for (const row of rows) {
    console.log(`  ${row.label}: ${row.count}`);
  }
  console.log('');
}

async function deleteExtraUsers(
  toDelete: Array<{ user: UserRow; reason: string }>
): Promise<void> {
  for (const entry of toDelete) {
    await pool.query('DELETE FROM email_deliveries WHERE user_id = $1;', [entry.user.id]);
    await pool.query('DELETE FROM users WHERE id = $1;', [entry.user.id]);
    console.log(`  ✓ usuario ${entry.user.username} (${entry.reason})`);
  }
}

async function resetGameplayForKeepUsers(keepIds: string[]): Promise<void> {
  if (keepIds.length === 0) {
    return;
  }

  await pool.query('BEGIN');
  try {
    await pool.query(`DELETE FROM games WHERE user_id = ANY($1::uuid[]);`, [keepIds]);

    await pool.query(`DELETE FROM history_games WHERE user_id = ANY($1::uuid[]);`, [keepIds]);

    await pool.query(
      `
        DELETE FROM history_games
        WHERE progress_id IN (
          SELECT pr.id
          FROM progress_restrictions pr
          INNER JOIN profiles p ON p.id = pr.profile_id
          WHERE p.user_id = ANY($1::uuid[])
        );
      `,
      [keepIds]
    );

    await pool.query(
      `
        DELETE FROM progress_restrictions
        WHERE profile_id IN (
          SELECT id FROM profiles WHERE user_id = ANY($1::uuid[])
        )
        OR user_id = ANY($1::uuid[]);
      `,
      [keepIds]
    );

    await pool.query(
      `
        UPDATE streaks s
        SET
          current_count = 0,
          best_count = 0,
          last_activity_day = NULL,
          last_activity_at = NULL,
          updated_at = now()
        FROM profiles p
        WHERE p.streak_id = s.id
          AND p.user_id = ANY($1::uuid[]);
      `,
      [keepIds]
    );

    await pool.query(
      `
        DELETE FROM streaks s
        WHERE s.id NOT IN (
          SELECT streak_id FROM profiles WHERE streak_id IS NOT NULL
        );
      `
    );

    await pool.query(
      `
        UPDATE profiles
        SET exp_count = 0, updated_at = now()
        WHERE user_id = ANY($1::uuid[]);
      `,
      [keepIds]
    );

    await pool.query(`DELETE FROM email_deliveries WHERE user_id = ANY($1::uuid[]);`, [keepIds]);
    await pool.query(
      `DELETE FROM email_verification_codes WHERE user_id = ANY($1::uuid[]);`,
      [keepIds]
    );
    if (await tableExists('password_reset_tokens')) {
      await pool.query(
        `DELETE FROM password_reset_tokens WHERE user_id = ANY($1::uuid[]);`,
        [keepIds]
      );
    }

    await pool.query(`TRUNCATE leaderboard_snapshots RESTART IDENTITY;`);
    await pool.query(
      `
        UPDATE leaderboard_meta
        SET
          last_refreshed_at = NULL,
          row_count = 0,
          duration_ms = 0,
          current_generation = 0,
          error_message = NULL;
      `
    );

    await pool.query('COMMIT');
  } catch (error) {
    await pool.query('ROLLBACK');
    throw error;
  }
}

async function main(): Promise<void> {
  const { apply, resetData, freeMail } = parseArgs();
  const users = await listUsers();
  const keepUsers = users.filter((user) =>
    KEEP_USERNAMES.includes(user.username as (typeof KEEP_USERNAMES)[number])
  );
  const toDelete = users
    .map((user) => {
      const reason = shouldDeleteUser(user, freeMail);
      return reason ? { user, reason } : null;
    })
    .filter((entry): entry is { user: UserRow; reason: string } => entry != null);

  console.log('═══════════════════════════════════════════');
  console.log(
    `  Limpieza staging (${apply ? 'APLICAR' : 'dry-run'}${resetData ? ', reset-data' : ''})`
  );
  console.log('═══════════════════════════════════════════\n');
  console.log(`Conservados: ${KEEP_USERNAMES.join(', ')}`);
  if (freeMail) {
    console.log(`Liberar mail: ${freeMail}`);
  }

  const before = await countGameplayRows();
  printCounts('Estado actual:', before);

  if (toDelete.length > 0) {
    console.log(`Usuarios extra a eliminar (${toDelete.length}):`);
    for (const entry of toDelete) {
      const mail = entry.user.mail ?? '(sin mail)';
      console.log(`  - ${entry.user.username} <${mail}> — ${entry.reason}`);
    }
    console.log('');
  } else {
    console.log('Usuarios extra a eliminar: 0\n');
  }

  if (resetData) {
    console.log('Reset de gameplay para usuarios conservados:');
    console.log('  - partidas, historial, progreso por restricción');
    console.log('  - rachas en cero');
    console.log('  - exp global en cero');
    console.log('  - mails transaccionales (OTP, deliveries, reset tokens)');
    console.log('  - leaderboard snapshots\n');
  }

  if (!apply) {
    console.log('Dry-run. Ejecutá con --apply para aplicar.');
    return;
  }

  console.log('Aplicando...\n');

  if (toDelete.length > 0) {
    await deleteExtraUsers(toDelete);
  }

  if (resetData) {
    const keepIds = keepUsers.map((user) => user.id);
    await resetGameplayForKeepUsers(keepIds);
    console.log('  ✓ gameplay reseteado para margo/agus');
  }

  const after = await countGameplayRows();
  printCounts('Estado final:', after);
  console.log('Listo.');
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
