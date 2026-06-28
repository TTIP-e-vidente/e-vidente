import { execSync } from 'child_process';
import { pool } from '../src/config/database';
import { isEmailDeliveryConfigured } from '../src/modules/email/email.config';
import { sendTransactionalEmail } from '../src/modules/email/email.client';
import { buildEmailMessage } from '../src/modules/email/templates';
import { EmailMessage, EmailTemplateKey } from '../src/modules/email/email.types';

const DEFAULT_TEST_EMAIL_TO = 'agusdisanto99@gmail.com';
const DEFAULT_TEST_EMAIL_NAME = 'Agus';

interface TestRecipient {
  mail: string;
  name: string;
  streakCount: number;
  lostStreakCount: number;
}

function resolveRecipientMail(): string {
  return (process.env.TEST_EMAIL_TO ?? process.env.SMOKE_EMAIL_TO ?? DEFAULT_TEST_EMAIL_TO).trim();
}

async function resolveTestRecipient(mail: string): Promise<TestRecipient> {
  const fallbackName =
    (process.env.TEST_EMAIL_NAME ?? DEFAULT_TEST_EMAIL_NAME).trim() || DEFAULT_TEST_EMAIL_NAME;

  try {
    const result = await pool.query<{
      name: string | null;
      current_count: number | null;
      best_count: number | null;
    }>(
      `
        SELECT
          u.name,
          COALESCE(s.current_count, 0) AS current_count,
          COALESCE(s.best_count, 0) AS best_count
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
        LEFT JOIN streaks s ON s.id = p.streak_id
        WHERE lower(u.mail) = lower($1)
        LIMIT 1
      `,
      [mail]
    );

    if (result.rows.length === 0) {
      console.warn(`[test:email] Usuario no encontrado para ${mail}. Usando datos de demo.`);
      return {
        mail,
        name: fallbackName,
        streakCount: 1,
        lostStreakCount: 1
      };
    }

    const row = result.rows[0];
    const currentCount = Math.max(0, Number(row.current_count) || 0);
    const bestCount = Math.max(currentCount, Number(row.best_count) || 0);
    const name = (row.name ?? '').trim() || fallbackName;

    return {
      mail,
      name,
      streakCount: currentCount > 0 ? currentCount : 1,
      lostStreakCount: bestCount > 0 ? bestCount : 1
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`[test:email] No se pudo leer racha desde DB (${message}). Usando datos de demo.`);
    return {
      mail,
      name: fallbackName,
      streakCount: 1,
      lostStreakCount: 1
    };
  }
}

function runUnitTests(): void {
  console.log('[test:email] Ejecutando tests de templates...\n');
  execSync('npx ts-node tests/email.templates.unit.test.ts', {
    stdio: 'inherit',
    cwd: process.cwd()
  });
}

function buildTestMessage(templateKey: EmailTemplateKey, recipient: TestRecipient): EmailMessage {
  const { mail, name, streakCount, lostStreakCount } = recipient;

  switch (templateKey) {
    case 'welcome':
      return buildEmailMessage('welcome', { name, mail });
    case 'email_verification':
      return buildEmailMessage('email_verification', {
        name,
        mail,
        code: '843184',
        expiresMinutes: 15
      });
    case 'streak_at_risk':
      return buildEmailMessage('streak_at_risk', { name, mail, streakCount });
    case 'streak_lost':
      return buildEmailMessage('streak_lost', { name, mail, streakCount: lostStreakCount });
    case 'mail_changed':
      return buildEmailMessage('mail_changed', {
        name,
        oldMail: mail,
        newMail: 'nuevo@example.com'
      });
    default:
      throw new Error(`Template no soportado: ${templateKey satisfies never}`);
  }
}

async function sendTemplate(templateKey: EmailTemplateKey, recipient: TestRecipient): Promise<void> {
  const message = buildTestMessage(templateKey, recipient);
  message.to = recipient.mail;
  message.toName = recipient.name;

  const messageId = await sendTransactionalEmail(message, { templateKey });
  console.log(`[test:email] OK ${templateKey} → ${recipient.mail} (messageId=${messageId ?? 'n/a'})`);
}

async function sendAllTemplates(recipient: TestRecipient): Promise<void> {
  const templates: EmailTemplateKey[] = [
    'email_verification',
    'welcome',
    'streak_at_risk',
    'streak_lost',
    'mail_changed'
  ];

  if (!isEmailDeliveryConfigured()) {
    console.warn(
      '[test:email] SKIP envío real — configurá EMAIL_ENABLED=true, BREVO_API_KEY y BREVO_SENDER_EMAIL.'
    );
    console.warn('[test:email] Los templates pasaron los tests unitarios igualmente.');
    return;
  }

  console.log(
    `\n[test:email] Enviando ${templates.length} mails a ${recipient.mail} ` +
      `(racha activa=${recipient.streakCount}, racha perdida demo=${recipient.lostStreakCount})...\n`
  );

  for (const templateKey of templates) {
    await sendTemplate(templateKey, recipient);
  }
}

async function run(): Promise<void> {
  const mail = resolveRecipientMail();
  const recipient = await resolveTestRecipient(mail);
  console.log(
    `[test:email] Destinatario: ${recipient.mail} (${recipient.name}) · racha DB=${recipient.streakCount}\n`
  );

  runUnitTests();
  await sendAllTemplates(recipient);

  console.log('\n[test:email] Completado.');
}

run()
  .catch((error) => {
    console.error('[test:email] Error', error);
    process.exit(1);
  })
  .finally(async () => {
    await pool.end();
  });
