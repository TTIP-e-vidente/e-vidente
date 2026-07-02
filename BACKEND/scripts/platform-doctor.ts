/**
 * Platform doctor: chequeo de salud de los subsistemas de la Platform V1.
 *
 * Uso:
 *   npm run platform:doctor            (usa .env)
 *   npm run platform:doctor:staging    (usa .env.staging)
 *
 * Verifica: DB, env vars, Brevo, Storage/avatars, crons, outbox de emails,
 * verificación de usuarios y anomalías de idempotencia (client_run_id).
 * Salida: OK / WARN / FAIL por subsistema. Exit code 1 si hay algún FAIL.
 */
import { loadEnvFile } from '../src/config/load-env';

loadEnvFile();

// Importar la pool después de cargar el env.
import { pool } from '../src/config/database';
import { isEmailDeliveryConfigured, emailConfig } from '../src/modules/email/email.config';

type Level = 'OK' | 'WARN' | 'FAIL';

interface CheckResult {
  subsystem: string;
  level: Level;
  detail: string;
}

const results: CheckResult[] = [];

function report(subsystem: string, level: Level, detail: string): void {
  results.push({ subsystem, level, detail });
}

async function checkDatabase(): Promise<boolean> {
  try {
    const r = await pool.query('SELECT now() AS now');
    report('db', 'OK', `Postgres accesible (${String(r.rows[0]?.now ?? '')})`);
    return true;
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    report('db', 'FAIL', `Postgres inaccesible: ${msg}`);
    return false;
  }
}

function checkEnvVars(): void {
  const required = ['JWT_SECRET', 'POSTGRES_HOST', 'POSTGRES_USER', 'POSTGRES_DB'];
  const missing = required.filter((name) => !(process.env[name] ?? '').trim());
  if (missing.length > 0) {
    report('env', 'FAIL', `Faltan variables: ${missing.join(', ')}`);
    return;
  }
  const jwtSecret = (process.env.JWT_SECRET ?? '').trim();
  if (jwtSecret.length < 16) {
    report('env', 'WARN', 'JWT_SECRET tiene menos de 16 caracteres');
    return;
  }
  report('env', 'OK', 'Variables requeridas presentes');
}

function checkBrevo(): void {
  const enabled = (process.env.EMAIL_ENABLED ?? '').trim().toLowerCase();
  const wantsEmail = ['true', '1', 'yes'].includes(enabled);
  if (!wantsEmail) {
    report('email', 'WARN', 'EMAIL_ENABLED no está activo: no se envían mails');
    return;
  }
  if (!isEmailDeliveryConfigured()) {
    report(
      'email',
      'FAIL',
      'EMAIL_ENABLED=true pero falta BREVO_API_KEY o BREVO_SENDER_EMAIL'
    );
    return;
  }
  const sender = emailConfig.senderEmail.toLowerCase();
  if (/@(gmail|hotmail|outlook|yahoo)\./.test(sender)) {
    report(
      'email',
      'WARN',
      `Sender ${emailConfig.senderEmail}: enviar como ${sender.split('@')[1]} vía Brevo ` +
        'suele caer en spam (SPF/DKIM desalineados). Verificá un dominio propio en Brevo.'
    );
    return;
  }
  report('email', 'OK', `Brevo configurado (sender: ${emailConfig.senderEmail})`);
}

function checkStorageEnv(): void {
  const url = (process.env.SUPABASE_URL ?? '').trim();
  const serviceRole = (process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
  const projectRef = (process.env.SUPABASE_PROJECT_REF ?? '').trim();
  if (url && serviceRole) {
    report('storage', 'OK', 'Storage de avatars configurado (SUPABASE_URL + SERVICE_ROLE_KEY)');
    return;
  }
  if (projectRef) {
    report(
      'storage',
      'WARN',
      'SUPABASE_PROJECT_REF presente pero sin SUPABASE_URL/SERVICE_ROLE_KEY locales; ' +
        'el Storage lo usan las Edge Functions con sus propios secrets'
    );
    return;
  }
  report('storage', 'WARN', 'Sin config de Supabase Storage: avatares caen a base64 legacy');
}

async function checkCron(): Promise<void> {
  try {
    const exists = await pool.query(
      `SELECT to_regclass('private.cron_invocation_log') AS t;`
    );
    if (!exists.rows[0]?.t) {
      report('cron', 'WARN', 'Tabla private.cron_invocation_log no existe (crons sin auditar)');
      return;
    }
    const r = await pool.query(
      `SELECT max(created_at) AS last FROM private.cron_invocation_log;`
    );
    const last: Date | null = r.rows[0]?.last ?? null;
    if (!last) {
      report('cron', 'WARN', 'Sin invocaciones de cron registradas todavía');
      return;
    }
    const ageMinutes = (Date.now() - new Date(last).getTime()) / 60000;
    if (ageMinutes > 90) {
      report(
        'cron',
        'WARN',
        `Última invocación de cron hace ${Math.round(ageMinutes)} min (esperado < 90 en staging/prod)`
      );
      return;
    }
    report('cron', 'OK', `Última invocación de cron hace ${Math.round(ageMinutes)} min`);
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    report('cron', 'WARN', `No se pudo consultar cron_invocation_log: ${msg}`);
  }
}

async function checkEmailOutbox(): Promise<void> {
  try {
    const r = await pool.query(
      `SELECT status, COUNT(*)::int AS count FROM email_deliveries GROUP BY status;`
    );
    const byStatus: Record<string, number> = {};
    for (const row of r.rows) {
      byStatus[String(row.status)] = Number(row.count);
    }
    const pending = byStatus.pending ?? 0;
    const failed = byStatus.failed ?? 0;
    const sent = byStatus.sent ?? 0;
    const stale = await pool.query(
      `
        SELECT COUNT(*)::int AS count
        FROM email_deliveries
        WHERE status = 'failed'
          AND failed_at < now() - INTERVAL '48 hours';
      `
    );
    const staleFailed = Number(stale.rows[0]?.count ?? 0);
    const detail = `sent=${sent} pending=${pending} failed=${failed} (failed>48h=${staleFailed})`;
    if (staleFailed > 0) {
      report('outbox', 'WARN', `Deliveries fallidos fuera de ventana de retry: ${detail}`);
      return;
    }
    if (failed > 20) {
      report('outbox', 'WARN', `Muchos deliveries fallidos: ${detail}`);
      return;
    }
    report('outbox', 'OK', detail);
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    report('outbox', 'WARN', `No se pudo resumir email_deliveries: ${msg}`);
  }
}

async function checkVerification(): Promise<void> {
  try {
    const r = await pool.query(
      `
        SELECT
          COUNT(*) FILTER (WHERE mail IS NOT NULL AND mail_verified_at IS NULL)::int AS unverified,
          COUNT(*) FILTER (WHERE mail IS NOT NULL)::int AS with_mail
        FROM users;
      `
    );
    const unverified = Number(r.rows[0]?.unverified ?? 0);
    const withMail = Number(r.rows[0]?.with_mail ?? 0);
    report('auth', 'OK', `Usuarios con mail: ${withMail}, sin verificar: ${unverified}`);
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    report('auth', 'WARN', `No se pudo consultar users: ${msg}`);
  }
}

async function checkAvatars(): Promise<void> {
  try {
    const r = await pool.query(
      `
        SELECT
          COUNT(*)::int AS total,
          COUNT(*) FILTER (WHERE storage_path IS NOT NULL)::int AS in_storage,
          COUNT(*) FILTER (WHERE storage_path IS NULL AND data IS NOT NULL)::int AS legacy_base64,
          COUNT(*) FILTER (WHERE storage_path IS NULL AND data IS NULL)::int AS empty_rows
        FROM images;
      `
    );
    const row = r.rows[0] ?? {};
    const emptyRows = Number(row.empty_rows ?? 0);
    const detail =
      `total=${row.total} storage=${row.in_storage} ` +
      `base64_legacy=${row.legacy_base64} vacíos=${emptyRows}`;
    if (emptyRows > 0) {
      report('avatars', 'WARN', `Filas de avatar sin contenido (${detail})`);
      return;
    }
    report('avatars', 'OK', detail);
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    report('avatars', 'WARN', `No se pudo consultar images: ${msg}`);
  }
}

async function checkSyncIdempotency(): Promise<void> {
  try {
    const r = await pool.query(
      `
        SELECT COUNT(*)::int AS dupes
        FROM (
          SELECT progress_id, client_run_id
          FROM games
          WHERE client_run_id IS NOT NULL
          GROUP BY progress_id, client_run_id
          HAVING COUNT(*) > 1
        ) d;
      `
    );
    const dupes = Number(r.rows[0]?.dupes ?? 0);
    if (dupes > 0) {
      report(
        'sync',
        'FAIL',
        `client_run_id duplicados en games: ${dupes} (la unique constraint debería impedirlo)`
      );
      return;
    }
    report('sync', 'OK', 'Sin client_run_id duplicados en games');
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    report('sync', 'WARN', `No se pudo verificar idempotencia: ${msg}`);
  }
}

function printResults(): void {
  const width = Math.max(...results.map((r) => r.subsystem.length));
  console.log('\n=== PLATFORM DOCTOR ===\n');
  for (const r of results) {
    const icon = r.level === 'OK' ? '✅' : r.level === 'WARN' ? '⚠️ ' : '❌';
    console.log(`${icon} [${r.level.padEnd(4)}] ${r.subsystem.padEnd(width)}  ${r.detail}`);
  }
  const fails = results.filter((r) => r.level === 'FAIL').length;
  const warns = results.filter((r) => r.level === 'WARN').length;
  console.log(
    `\nResumen: ${results.length} chequeos — ${fails} FAIL, ${warns} WARN, ` +
      `${results.length - fails - warns} OK\n`
  );
}

async function main(): Promise<void> {
  checkEnvVars();
  checkBrevo();
  checkStorageEnv();

  const dbOk = await checkDatabase();
  if (dbOk) {
    await checkEmailOutbox();
    await checkVerification();
    await checkAvatars();
    await checkSyncIdempotency();
    await checkCron();
  }

  printResults();
  await pool.end();

  if (results.some((r) => r.level === 'FAIL')) {
    process.exitCode = 1;
  }
}

void main().catch(async (error) => {
  console.error('[platform:doctor] error inesperado:', error);
  try {
    await pool.end();
  } catch {
    // ignorar
  }
  process.exitCode = 1;
});
