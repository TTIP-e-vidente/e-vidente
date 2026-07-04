/**
 * Dispara crons de staging para UN usuario y UN mail por template.
 *
 * Uso:
 *   npm run cron:dispatch:staging -- margarita.cortizas@gmail.com
 *   npm run cron:dispatch:staging -- margarita.cortizas@gmail.com --job streak-at-risk-emails
 *   npm run cron:dispatch:staging -- margarita.cortizas@gmail.com --force-resend
 */
import { PoolClient } from 'pg';
import { getTodayInConfiguredTimezone } from '../src/modules/email/email.service';
import { emailConfig } from '../src/modules/email/email.config';
import {
  assertSupabaseStagingEnv,
  connectSupabase,
  createPoolFromCurrentEnv,
  describeConnection,
} from './lib/postgres-env';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  assertInternalJobEnv,
  CONFIGURED_CRON_JOBS,
  type ConfiguredCronJob,
  triggerInternalJob,
} from './lib/internal-job-client';

const EMAIL_CRON_JOBS = CONFIGURED_CRON_JOBS.filter((job) => job !== 'refresh-leaderboard');

interface TargetUser {
  id: string;
  mail: string;
  name: string;
}

interface JobMailSpec {
  templateKey: string;
  dedupeKey: string;
}

interface ParsedArgs {
  mail: string;
  dryRun: boolean;
  skipLeaderboard: boolean;
  skipRetry: boolean;
  forceResend: boolean;
  pauseSeconds: number;
  onlyJob: ConfiguredCronJob | null;
}

function shiftDateIso(dateIso: string, dayDelta: number): string {
  const anchor = new Date(`${dateIso}T12:00:00.000Z`);
  anchor.setUTCDate(anchor.getUTCDate() + dayDelta);
  return anchor.toISOString().slice(0, 10);
}

function sleep(seconds: number): Promise<void> {
  if (seconds <= 0) {
    return Promise.resolve();
  }
  return new Promise((resolve) => {
    setTimeout(resolve, seconds * 1000);
  });
}

function parseArgs(argv: string[]): ParsedArgs {
  const flags = new Set(argv.filter((arg) => arg.startsWith('--')));
  const positional = argv.filter((arg) => !arg.startsWith('--'));
  const mailFlagIndex = argv.indexOf('--mail');
  const mailFromFlag = mailFlagIndex >= 0 ? argv[mailFlagIndex + 1]?.trim() : '';
  const mailFromPositional = positional.find((arg) => arg.includes('@'))?.trim() ?? '';
  const mail =
    mailFromFlag
    || mailFromPositional
    || process.env.CRON_DISPATCH_MAIL?.trim()
    || process.env.TEST_EMAIL_TO?.trim()
    || '';

  const jobFlagIndex = argv.indexOf('--job');
  const jobRaw = jobFlagIndex >= 0 ? argv[jobFlagIndex + 1]?.trim() : '';
  const onlyJob = CONFIGURED_CRON_JOBS.includes(jobRaw as ConfiguredCronJob)
    ? (jobRaw as ConfiguredCronJob)
    : null;
  if (jobRaw && !onlyJob) {
    console.error(`Job desconocido: ${jobRaw}`);
    console.error(`Válidos: ${CONFIGURED_CRON_JOBS.join(', ')}`);
    process.exit(1);
  }

  const pauseFlagIndex = argv.indexOf('--pause-seconds');
  const pauseFromFlag = pauseFlagIndex >= 0 ? Number.parseInt(argv[pauseFlagIndex + 1] ?? '', 10) : NaN;
  const pauseSeconds = Number.isFinite(pauseFromFlag) && pauseFromFlag >= 0 ? pauseFromFlag : 15;

  if (!mail || !mail.includes('@')) {
    console.error('Uso: npm run cron:dispatch:staging -- <mail@ejemplo.com>');
    console.error('     npm run cron:dispatch:staging -- <mail> [--job streak-at-risk-emails]');
    console.error('     npm run cron:dispatch:staging -- <mail> [--force-resend] [--skip-retry]');
    process.exit(1);
  }

  return {
    mail,
    dryRun: flags.has('--dry-run'),
    skipLeaderboard: flags.has('--skip-leaderboard'),
    skipRetry: flags.has('--skip-retry'),
    forceResend: flags.has('--force-resend'),
    pauseSeconds,
    onlyJob,
  };
}

async function findTargetUser(client: PoolClient, mail: string): Promise<TargetUser> {
  const result = await client.query<{
    id: string;
    mail: string;
    name: string | null;
    mail_verified_at: Date | null;
    email_notifications_enabled: boolean | null;
  }>(
    `
      SELECT u.id, u.mail, u.name, u.mail_verified_at, u.email_notifications_enabled
      FROM users u
      WHERE lower(u.mail) = lower($1)
      LIMIT 1;
    `,
    [mail],
  );

  const row = result.rows[0];
  if (!row) {
    throw new Error(`No hay usuario con mail ${mail} en ${describeConnection()}`);
  }
  if (!row.mail_verified_at) {
    throw new Error(`${mail} existe pero mail_verified_at es NULL — verificá el mail antes.`);
  }
  if (row.email_notifications_enabled === false) {
    await client.query(
      `UPDATE users SET email_notifications_enabled = true, updated_at = now() WHERE id = $1;`,
      [row.id],
    );
    console.warn(`[cron-dispatch] email_notifications_enabled=true activado para ${mail} (staging)`);
  }

  return {
    id: row.id,
    mail: row.mail,
    name: (row.name ?? 'Jugador').trim() || 'Jugador',
  };
}

async function ensureStreak(client: PoolClient, userId: string): Promise<void> {
  const profile = await client.query<{ streak_id: string | null }>(
    `SELECT streak_id FROM profiles WHERE user_id = $1 LIMIT 1;`,
    [userId],
  );
  if (!profile.rows[0]) {
    throw new Error('El usuario no tiene profile — creá el perfil en juego antes de disparar crons.');
  }
  if (profile.rows[0].streak_id) {
    return;
  }

  const inserted = await client.query<{ id: string }>(
    `
      INSERT INTO streaks (current_count, best_count, last_activity_day, last_activity_at)
      VALUES (1, 1, (now() AT TIME ZONE $2)::date, now())
      RETURNING id;
    `,
    [userId, emailConfig.timezone],
  );
  await client.query(
    `UPDATE profiles SET streak_id = $2, updated_at = now() WHERE user_id = $1;`,
    [userId, inserted.rows[0].id],
  );
}

async function setStreakState(
  client: PoolClient,
  userId: string,
  currentCount: number,
  lastActivityDay: string,
): Promise<void> {
  await client.query(
    `
      UPDATE streaks s
      SET
        current_count = $2,
        best_count = GREATEST(s.best_count, $2),
        last_activity_day = $3::date,
        last_activity_at = ($3::date + time '20:00') AT TIME ZONE $4,
        updated_at = now()
      FROM profiles p
      WHERE p.user_id = $1
        AND p.streak_id = s.id;
    `,
    [userId, currentCount, lastActivityDay, emailConfig.timezone],
  );
}

async function hasDeliverySent(
  client: PoolClient,
  userId: string,
  templateKey: string,
  dedupeKey: string,
): Promise<boolean> {
  const result = await client.query<{ exists: boolean }>(
    `
      SELECT EXISTS (
        SELECT 1
        FROM email_deliveries
        WHERE user_id = $1
          AND template_key = $2
          AND dedupe_key = $3
          AND status = 'sent'
      ) AS exists;
    `,
    [userId, templateKey, dedupeKey],
  );
  return Boolean(result.rows[0]?.exists);
}

async function clearDeliveryRecord(
  client: PoolClient,
  userId: string,
  templateKey: string,
  dedupeKey: string,
): Promise<void> {
  await client.query(
    `
      DELETE FROM email_deliveries
      WHERE user_id = $1
        AND template_key = $2
        AND dedupe_key = $3;
    `,
    [userId, templateKey, dedupeKey],
  );
}

async function freezeOtherFailedRetries(client: PoolClient, targetUserId: string): Promise<void> {
  await client.query(
    `
      UPDATE email_deliveries
      SET next_attempt_at = now() + interval '7 days'
      WHERE status = 'failed'
        AND NOT (user_id = $1 AND dedupe_key = 'cron-dispatch-retry-demo');
    `,
    [targetUserId],
  );
}

async function seedRetryCandidate(client: PoolClient, user: TargetUser): Promise<void> {
  await freezeOtherFailedRetries(client, user.id);
  await client.query(
    `DELETE FROM email_deliveries WHERE user_id = $1 AND dedupe_key = 'cron-dispatch-retry-demo';`,
    [user.id],
  );
  await client.query(
    `
      INSERT INTO email_deliveries (
        user_id, template_key, dedupe_key, recipient_email, subject,
        status, error_message, failed_at, attempt_count, next_attempt_at
      )
      VALUES (
        $1, 'welcome', 'cron-dispatch-retry-demo', $2, 'Welcome demo retry',
        'failed', 'cron-dispatch seed', now() - interval '47 hours', 1, now()
      );
    `,
    [user.id, user.mail],
  );
}

function mailSpecForJob(
  job: ConfiguredCronJob,
  today: string,
  lostDay: string,
): JobMailSpec | null {
  switch (job) {
    case 'streak-at-risk-emails':
      return { templateKey: 'streak_at_risk', dedupeKey: `at_risk:${today}` };
    case 'streak-last-chance-emails':
      return { templateKey: 'streak_last_chance', dedupeKey: `last_chance:${today}` };
    case 'streak-lost-emails':
      return { templateKey: 'streak_lost', dedupeKey: `lost:${lostDay}` };
    case 'retry-failed-emails':
      return { templateKey: 'welcome', dedupeKey: 'cron-dispatch-retry-demo' };
    default:
      return null;
  }
}

async function prepareForJob(
  client: PoolClient,
  user: TargetUser,
  job: ConfiguredCronJob,
  today: string,
  yesterday: string,
  lostDay: string,
  forceResend: boolean,
): Promise<void> {
  const spec = mailSpecForJob(job, today, lostDay);
  if (spec && forceResend) {
    await clearDeliveryRecord(client, user.id, spec.templateKey, spec.dedupeKey);
  }

  if (job === 'streak-at-risk-emails') {
    await setStreakState(client, user.id, 7, yesterday);
    return;
  }
  if (job === 'streak-last-chance-emails') {
    await setStreakState(client, user.id, 7, yesterday);
    return;
  }
  if (job === 'streak-lost-emails') {
    await setStreakState(client, user.id, 7, lostDay);
    return;
  }
  if (job === 'retry-failed-emails') {
    await seedRetryCandidate(client, user);
  }
}

function extractSentCount(job: ConfiguredCronJob, body: string): number | null {
  try {
    const payload = JSON.parse(body) as Record<string, unknown>;
    const bucket =
      job === 'streak-at-risk-emails' ? payload.atRisk
      : job === 'streak-last-chance-emails' ? payload.lastChance
      : job === 'streak-lost-emails' ? payload.lost
      : job === 'retry-failed-emails' ? payload.retry
      : null;
    if (bucket && typeof bucket === 'object' && bucket !== null && 'sent' in bucket) {
      return Number((bucket as { sent: number }).sent);
    }
  } catch {
    return null;
  }
  return null;
}

async function runJob(
  job: ConfiguredCronJob,
  userId: string,
  dryRun: boolean,
): Promise<{ ok: boolean; summary: string; sent: number | null; skipped: boolean }> {
  if (dryRun) {
    console.log(`  [dry-run] POST internal-job { job: "${job}", onlyUserId: "${userId}" }`);
    return { ok: true, summary: 'dry-run', sent: null, skipped: false };
  }

  const result = await triggerInternalJob(job, {
    onlyUserId: userId,
    retryBatchLimit: job === 'retry-failed-emails' ? 1 : undefined,
  });
  console.log(`  HTTP ${result.status}`);
  console.log(`  ${result.body}`);

  const sent = extractSentCount(job, result.body);
  if (sent !== null && sent > 1) {
    throw new Error(`${job} envió ${sent} mails (esperado 0 o 1)`);
  }

  return {
    ok: result.status >= 200 && result.status < 300,
    summary: result.body,
    sent,
    skipped: false,
  };
}

function resolveJobs(args: ParsedArgs): ConfiguredCronJob[] {
  if (args.onlyJob) {
    return [args.onlyJob];
  }
  const jobs: ConfiguredCronJob[] = args.skipRetry
    ? EMAIL_CRON_JOBS.filter((job) => job !== 'retry-failed-emails')
    : [...EMAIL_CRON_JOBS];
  if (!args.skipLeaderboard) {
    jobs.push('refresh-leaderboard');
  }
  return jobs;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const loaded = loadStagingWithKeys();
  assertSupabaseStagingEnv(loaded.envPath);
  assertInternalJobEnv();

  const today = getTodayInConfiguredTimezone();
  const yesterday = shiftDateIso(today, -1);
  const lostDay = shiftDateIso(today, -2);
  const jobs = resolveJobs(args);
  const sentThisRun = new Set<string>();

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — cron dispatch por mail');
  console.log('═══════════════════════════════════════════');
  console.log(`Destino: ${args.mail}`);
  console.log(`DB: ${describeConnection()}`);
  console.log(`Hoy (${emailConfig.timezone}): ${today}`);
  console.log(`Jobs: ${jobs.join(', ')}`);
  console.log(`Pausa entre mails: ${args.pauseSeconds}s`);
  console.log(`Reenvío forzado: ${args.forceResend ? 'sí' : 'no (salta si ya se envió hoy)'}`);
  if (args.dryRun) {
    console.log('Modo: dry-run\n');
  } else {
    console.log('');
  }

  await connectSupabase({ envPath: loaded.envPath, persistToEnvFile: true });
  const pool = createPoolFromCurrentEnv({ connectionTimeoutMillis: 20000 });
  const client = await pool.connect();

  try {
    const user = args.dryRun
      ? { id: '(dry-run)', mail: args.mail, name: 'Jugador' }
      : await findTargetUser(client, args.mail);

    console.log(`Usuario: ${user.name} <${user.mail}> (${user.id})\n`);

    if (!args.dryRun) {
      await ensureStreak(client, user.id);
    }

    for (let index = 0; index < jobs.length; index += 1) {
      const job = jobs[index];
      const spec = mailSpecForJob(job, today, lostDay);

      console.log(`▶ ${job}${spec ? ` → ${spec.templateKey}` : ''}`);

      if (spec) {
        if (sentThisRun.has(spec.templateKey)) {
          console.log(`  SKIP ya enviado en esta corrida (${spec.templateKey})`);
          console.log('');
          continue;
        }

        if (!args.dryRun && !args.forceResend) {
          const alreadySent = await hasDeliverySent(client, user.id, spec.templateKey, spec.dedupeKey);
          if (alreadySent) {
            console.log(`  SKIP ya enviado hoy (${spec.templateKey} / ${spec.dedupeKey})`);
            console.log('  Usá --force-resend si querés mandarlo otra vez.');
            console.log('');
            continue;
          }
        }
      }

      if (!args.dryRun) {
        await prepareForJob(client, user, job, today, yesterday, lostDay, args.forceResend);
      }

      console.log('  → internal-job (onlyUserId)');
      const result = await runJob(job, user.id, args.dryRun);
      if (!result.ok) {
        throw new Error(`${job} falló`);
      }

      if (spec && (result.sent === 1 || args.dryRun)) {
        sentThisRun.add(spec.templateKey);
      }

      const nextJob = jobs[index + 1];
      const nextSpec = nextJob ? mailSpecForJob(nextJob, today, lostDay) : null;
      if (spec && nextSpec && args.pauseSeconds > 0) {
        console.log(`  … pausa ${args.pauseSeconds}s`);
        await sleep(args.pauseSeconds);
      }
      console.log('');
    }

    console.log('═══════════════════════════════════════════');
    console.log('  cron-dispatch OK');
    console.log('═══════════════════════════════════════════');
    console.log(`Templates enviados en esta corrida: ${sentThisRun.size ? [...sentThisRun].join(', ') : '(ninguno nuevo)'}`);
    console.log('Máximo 1 mail por template. Reenvío: --force-resend');
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error('\ncron-dispatch falló:', error instanceof Error ? error.message : error);
  process.exit(1);
});
