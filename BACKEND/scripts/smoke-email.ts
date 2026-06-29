import { pool } from '../src/config/database';
import { emailConfig, isEmailDeliveryConfigured } from '../src/modules/email/email.config';
import { sendTransactionalEmail } from '../src/modules/email/email.client';
import * as emailRepository from '../src/modules/email/email.repository';
import {
  listEmailTemplateMetadata,
  previewEmailTemplate
} from '../src/modules/email/templates';
import { EmailTemplateKey } from '../src/modules/email/email.types';

function logStep(step: string, message: string): void {
  console.log(`[smoke:email] ${step} ${message}`);
}

function logOk(step: string, message: string): void {
  logStep(step, `OK — ${message}`);
}

function logFail(step: string, message: string): never {
  console.error(`[smoke:email] ${step} FAIL — ${message}`);
  process.exit(1);
}

function logWarn(step: string, message: string): void {
  console.warn(`[smoke:email] ${step} WARN — ${message}`);
}

function checkConfiguration(): void {
  const issues: string[] = [];

  if (!emailConfig.enabled) {
    issues.push('EMAIL_ENABLED=false');
  }
  if (emailConfig.brevoApiKey.length === 0) {
    issues.push('BREVO_API_KEY vacía');
  }
  if (emailConfig.senderEmail.length === 0) {
    issues.push('BREVO_SENDER_EMAIL vacío');
  }

  if (issues.length > 0) {
    logFail('1/4 Config', issues.join('; '));
  }

  if (!isEmailDeliveryConfigured()) {
    logFail('1/4 Config', 'isEmailDeliveryConfigured()=false');
  }

  logOk(
    '1/4 Config',
    `sender=${emailConfig.senderEmail} timezone=${emailConfig.timezone} timeout=${emailConfig.requestTimeoutMs}ms`
  );
}

function checkTemplatePreviews(): void {
  const metadata = listEmailTemplateMetadata();
  if (metadata.length === 0) {
    logFail('2/4 Templates', 'ningún template registrado');
  }

  for (const entry of metadata) {
    const templateKey = entry.key as EmailTemplateKey;
    const preview = previewEmailTemplate(templateKey);

    if (!preview.subject.trim()) {
      logFail('2/4 Templates', `${templateKey}: subject vacío`);
    }
    if (!preview.htmlContent.includes('E-VIDENTE')) {
      logFail('2/4 Templates', `${templateKey}: HTML sin marca E-VIDENTE`);
    }
    if (!preview.textContent.trim()) {
      logFail('2/4 Templates', `${templateKey}: textContent vacío`);
    }

    logStep('2/4 Templates', `${templateKey} → "${preview.subject}"`);
  }

  logOk('2/4 Templates', `${metadata.length} previews generados`);
}

async function checkRecentDeliveries(): Promise<void> {
  try {
    const deliveries = await emailRepository.listDeliveries({ limit: 10 });
    const summary = deliveries
      .slice(0, 5)
      .map((row) => `${row.template_key}:${row.status}`)
      .join(', ');

    logOk(
      '3/4 Deliveries',
      `${deliveries.length} filas recientes${summary ? ` (${summary})` : ''}`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    logFail('3/4 Deliveries', `no se pudo leer email_deliveries: ${message}`);
  }
}

async function optionalSendWelcome(): Promise<void> {
  const shouldSend = process.argv.includes('--send');
  const sendTo = process.env.SMOKE_EMAIL_TO?.trim() ?? '';

  if (!shouldSend) {
    logStep(
      '4/4 Send',
      'SKIP — usar --send y SMOKE_EMAIL_TO=tu@mail.com para envío real de prueba'
    );
    return;
  }

  if (!sendTo) {
    logFail('4/4 Send', 'falta SMOKE_EMAIL_TO en el entorno');
  }

  const message = previewEmailTemplate('welcome', {
    name: 'Smoke Test',
    mail: sendTo
  });
  message.to = sendTo;
  message.toName = 'Smoke Test';

  try {
    const messageId = await sendTransactionalEmail(message, { templateKey: 'welcome' });
    logOk('4/4 Send', `welcome enviado a ${sendTo} (messageId=${messageId ?? 'n/a'})`);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    logFail('4/4 Send', detail);
  }
}

async function run(): Promise<void> {
  console.log('[smoke:email] Iniciando validación del módulo de emails...\n');

  checkConfiguration();
  checkTemplatePreviews();
  await checkRecentDeliveries();
  await optionalSendWelcome();

  console.log('\n[smoke:email] Completado sin errores.');
}

run()
  .catch((error) => {
    console.error('[smoke:email] Error inesperado', error);
    process.exit(1);
  })
  .finally(async () => {
    await pool.end();
  });
