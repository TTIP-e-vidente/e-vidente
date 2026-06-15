import dotenv from 'dotenv';
import { pool } from '../src/config/database';
import { emailConfig, isEmailDeliveryConfigured } from '../src/modules/email/email.config';
import {
  enqueueWelcomeEmail,
  getTodayInConfiguredTimezone,
  runOutboundEmailJob
} from '../src/modules/email/email.service';
import * as emailRepository from '../src/modules/email/email.repository';
import { previewEmailTemplate } from '../src/modules/email/templates';
import { EmailTemplateKey } from '../src/modules/email/email.types';
import bcrypt from 'bcryptjs';
import { authConfig } from '../src/config/auth';
import * as profileRepository from '../src/modules/profile/profile.repository';
import * as streakRepository from '../src/modules/streak/streak.repository';
import { PoolClient } from 'pg';

dotenv.config();

const TEMPLATE_KEYS: EmailTemplateKey[] = ['welcome', 'streak_at_risk', 'streak_lost'];
const VALIDATION_USERNAME = process.env.EMAIL_VALIDATE_USERNAME ?? 'email_flow_validate';
const VALIDATION_MAIL = process.env.EMAIL_VALIDATE_MAIL ?? 'email.flow.validate@evidente.test';
const VALIDATION_PASSWORD = process.env.EMAIL_VALIDATE_PASSWORD ?? 'Password123';

type StepStatus = 'PASS' | 'FAIL' | 'SKIP' | 'WARN';

interface ValidationStep {
  id: string;
  label: string;
  status: StepStatus;
  detail: string;
}

const steps: ValidationStep[] = [];

function recordStep(
  id: string,
  label: string,
  status: StepStatus,
  detail: string
): void {
  steps.push({ id, label, status, detail });
  const prefix = `[validate:email-flow] ${id} ${status}`;
  if (status === 'FAIL') {
    console.error(`${prefix} — ${detail}`);
  } else if (status === 'WARN' || status === 'SKIP') {
    console.warn(`${prefix} — ${detail}`);
  } else {
    console.log(`${prefix} — ${detail}`);
  }
}

function shiftDateIso(dateIso: string, dayDelta: number): string {
  const anchor = new Date(`${dateIso}T12:00:00.000Z`);
  anchor.setUTCDate(anchor.getUTCDate() + dayDelta);
  return anchor.toISOString().slice(0, 10);
}

async function checkDatabase(): Promise<void> {
  try {
    const result = await pool.query<{ ok: number }>('SELECT 1 AS ok;');
    if (result.rows[0]?.ok === 1) {
      recordStep('db', 'PostgreSQL', 'PASS', 'Conexión OK');
      return;
    }
    recordStep('db', 'PostgreSQL', 'FAIL', 'Respuesta inesperada');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    recordStep('db', 'PostgreSQL', 'FAIL', message);
  }
}

function checkConfiguration(): void {
  if (!isEmailDeliveryConfigured()) {
    const issues: string[] = [];
    if (!emailConfig.enabled) issues.push('EMAIL_ENABLED=false');
    if (!emailConfig.brevoApiKey) issues.push('BREVO_API_KEY vacía');
    if (!emailConfig.senderEmail) issues.push('BREVO_SENDER_EMAIL vacío');
    recordStep('config', 'Brevo / .env', 'FAIL', issues.join('; ') || 'Config incompleta');
    return;
  }
  recordStep(
    'config',
    'Brevo / .env',
    'PASS',
    `sender=${emailConfig.senderEmail} startup=${emailConfig.processOnStartup}`
  );
}

function checkTemplates(): void {
  try {
    for (const templateKey of TEMPLATE_KEYS) {
      const preview = previewEmailTemplate(templateKey, {
        name: 'Validate',
        mail: VALIDATION_MAIL,
        streak_count: 5
      });
      if (!preview.subject.trim() || !preview.htmlContent.trim()) {
        recordStep('templates', 'Templates HTML', 'FAIL', `${templateKey} incompleto`);
        return;
      }
    }
    recordStep('templates', 'Templates HTML', 'PASS', `${TEMPLATE_KEYS.length} templates OK`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    recordStep('templates', 'Templates HTML', 'FAIL', message);
  }
}

async function upsertValidationUser(client: PoolClient, passwordHash: string): Promise<string> {
  const result = await client.query<{ id: string }>(
    `
      INSERT INTO users (
        username,
        name,
        display_name,
        mail,
        password_hash,
        email_notifications_enabled
      )
      VALUES ($1, $2, $2, $3, $4, true)
      ON CONFLICT (username)
      DO UPDATE SET
        name = EXCLUDED.name,
        display_name = EXCLUDED.display_name,
        mail = EXCLUDED.mail,
        password_hash = EXCLUDED.password_hash,
        email_notifications_enabled = true,
        updated_at = now()
      RETURNING id;
    `,
    [VALIDATION_USERNAME, 'Email Flow Validate', VALIDATION_MAIL, passwordHash]
  );
  return result.rows[0].id;
}

async function seedStreakCandidate(): Promise<boolean> {
  const today = getTodayInConfiguredTimezone();
  const yesterday = shiftDateIso(today, -1);
  const passwordHash = await bcrypt.hash(VALIDATION_PASSWORD, authConfig.bcryptSaltRounds);

  const client = await pool.connect();
  let userId = '';
  try {
    await client.query('BEGIN');
    userId = await upsertValidationUser(client, passwordHash);
    const profile = await profileRepository.ensureProfile(client, userId, 'CELIAQUIA');
    await streakRepository.ensureStreak(client, userId, profile.id);
    await client.query(
      `
        UPDATE streaks s
        SET
          current_count = 5,
          best_count = GREATEST(s.best_count, 5),
          last_activity_day = $2::date,
          updated_at = now()
        FROM profiles p
        WHERE p.user_id = $1
          AND p.streak_id = s.id;
      `,
      [userId, yesterday]
    );
    await client.query(
      `
        DELETE FROM email_deliveries
        WHERE user_id = $1
          AND template_key = 'streak_at_risk'
          AND dedupe_key = 'at_risk:' || $2;
      `,
      [userId, today]
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    const message = error instanceof Error ? error.message : String(error);
    recordStep('seed', 'Seed racha demo', 'FAIL', message);
    return false;
  } finally {
    client.release();
  }

  const candidates = await emailRepository.findStreakAtRiskCandidates(today);
  const isCandidate = candidates.some((row) => row.userId === userId);
  if (!isCandidate) {
    recordStep('seed', 'Seed racha demo', 'FAIL', 'Usuario no califica como streak_at_risk');
    return false;
  }

  recordStep(
    'seed',
    'Seed racha demo',
    'PASS',
    `user=${VALIDATION_USERNAME} last_activity_day=${yesterday}`
  );
  return true;
}

async function checkWelcomeOutbox(): Promise<void> {
  if (!isEmailDeliveryConfigured()) {
    recordStep('outbox', 'Welcome outbox', 'SKIP', 'EMAIL deshabilitado');
    return;
  }

  try {
    const user = await pool.query<{ id: string }>(
      'SELECT id FROM users WHERE username = $1;',
      [VALIDATION_USERNAME]
    );
    const userId = user.rows[0]?.id;
    if (!userId) {
      recordStep('outbox', 'Welcome outbox', 'FAIL', 'Usuario de validación no existe');
      return;
    }

    await pool.query(
      `
        DELETE FROM email_deliveries
        WHERE user_id = $1
          AND template_key = 'welcome'
          AND dedupe_key = 'welcome'
          AND status IN ('pending', 'failed');
      `,
      [userId]
    );

    const queued = await enqueueWelcomeEmail({
      userId,
      mail: VALIDATION_MAIL,
      name: 'Email Flow Validate'
    });
    if (queued !== 'queued') {
      recordStep('outbox', 'Welcome outbox', 'FAIL', `enqueue devolvió ${queued}`);
      return;
    }

    const pendingBefore = await emailRepository.findPendingWelcomeDeliveries(10);
    const hasPending = pendingBefore.some((row) => row.userId === userId);
    if (!hasPending) {
      recordStep('outbox', 'Welcome outbox', 'FAIL', 'No quedó fila pending en DB');
      return;
    }

    recordStep('outbox', 'Welcome outbox enqueue', 'PASS', 'pending persistido en email_deliveries');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    recordStep('outbox', 'Welcome outbox', 'FAIL', message);
  }
}

async function runOutboundAndVerify(): Promise<void> {
  if (!isEmailDeliveryConfigured()) {
    recordStep('outbound', 'Job outbound', 'SKIP', 'EMAIL deshabilitado');
    return;
  }

  try {
    const result = await runOutboundEmailJob();
    const welcomeSent = result.pendingWelcome.sent;
    const atRiskSent = result.atRisk.sent;
    const atRiskFailed = result.atRisk.failed;

    if (welcomeSent > 0) {
      recordStep('outbound', 'Welcome enviado', 'PASS', `sent=${welcomeSent}`);
    } else if (result.pendingWelcome.failed > 0) {
      recordStep(
        'outbound',
        'Welcome enviado',
        'FAIL',
        'Falló envío (revisar IP autorizada en Brevo)'
      );
    } else {
      recordStep('outbound', 'Welcome enviado', 'WARN', 'Sin envíos (quizá ya estaba sent)');
    }

    if (atRiskSent > 0) {
      recordStep('outbound', 'Streak at_risk enviado', 'PASS', `sent=${atRiskSent}`);
    } else if (atRiskFailed > 0) {
      recordStep(
        'outbound',
        'Streak at_risk enviado',
        'FAIL',
        `failed=${atRiskFailed} (revisar Brevo/IP)`
      );
    } else {
      recordStep('outbound', 'Streak at_risk enviado', 'WARN', 'Sin envíos en esta corrida');
    }

    recordStep(
      'outbound',
      'Job outbound',
      'PASS',
      `reconciledStreaks=${result.reconciledStreaks} retry.sent=${result.retry.sent}`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    recordStep('outbound', 'Job outbound', 'FAIL', message);
  }
}

async function checkDeliveriesAudit(): Promise<void> {
  try {
    const deliveries = await emailRepository.listDeliveries({ limit: 20 });
    const sent = deliveries.filter((row) => row.status === 'sent').length;
    const failed = deliveries.filter((row) => row.status === 'failed').length;
    const pending = deliveries.filter((row) => row.status === 'pending').length;

    if (sent === 0 && failed > 0) {
      recordStep(
        'audit',
        'Auditoría email_deliveries',
        'FAIL',
        `sent=0 failed=${failed} pending=${pending}`
      );
      return;
    }

    if (sent > 0) {
      recordStep(
        'audit',
        'Auditoría email_deliveries',
        'PASS',
        `sent=${sent} failed=${failed} pending=${pending}`
      );
      return;
    }

    recordStep(
      'audit',
      'Auditoría email_deliveries',
      'WARN',
      `Sin filas sent aún (failed=${failed} pending=${pending})`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    recordStep('audit', 'Auditoría email_deliveries', 'FAIL', message);
  }
}

function printSummary(): void {
  console.log('\n[validate:email-flow] === RESUMEN ===');
  for (const step of steps) {
    console.log(`  [${step.status}] ${step.label}: ${step.detail}`);
  }

  const failures = steps.filter((step) => step.status === 'FAIL').length;
  const warnings = steps.filter((step) => step.status === 'WARN').length;
  console.log(
    `\n[validate:email-flow] ${failures === 0 ? 'COMPLETADO' : 'CON FALLOS'} — fail=${failures} warn=${warnings}`
  );

  if (failures > 0) {
    console.log(
      '[validate:email-flow] Tip: revisá BREVO_SETUP.md (IP autorizada, API key, remitente verified)'
    );
    process.exit(1);
  }
}

async function cleanupValidationUser(): Promise<void> {
  await pool.query(
    `
      DELETE FROM email_deliveries
      WHERE user_id IN (SELECT id FROM users WHERE username = $1);
    `,
    [VALIDATION_USERNAME]
  );
  await pool.query('DELETE FROM users WHERE username = $1;', [VALIDATION_USERNAME]);
}

async function run(): Promise<void> {
  console.log('[validate:email-flow] Validación end-to-end del circuito de mails\n');

  await checkDatabase();
  checkConfiguration();
  checkTemplates();

  if (steps.some((step) => step.id === 'db' && step.status === 'FAIL')) {
    printSummary();
    return;
  }

  await seedStreakCandidate();
  await checkWelcomeOutbox();
  await runOutboundAndVerify();
  await checkDeliveriesAudit();

  if (process.argv.includes('--cleanup')) {
    await cleanupValidationUser();
    recordStep('cleanup', 'Limpieza', 'PASS', `Usuario ${VALIDATION_USERNAME} eliminado`);
  } else {
    recordStep(
      'cleanup',
      'Limpieza',
      'SKIP',
      'Usar --cleanup para borrar usuario de validación'
    );
  }

  printSummary();
}

run()
  .catch((error) => {
    console.error('[validate:email-flow] Error inesperado', error);
    process.exit(1);
  })
  .finally(async () => {
    await pool.end();
  });
