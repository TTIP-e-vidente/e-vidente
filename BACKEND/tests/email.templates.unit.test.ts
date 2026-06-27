process.env.EMAIL_CRON_SECRET = process.env.EMAIL_CRON_SECRET || 'email-template-test-secret';
process.env.BACKEND_BASE_URL = process.env.BACKEND_BASE_URL || 'https://api.example.com';

import assert from 'assert/strict';
import {
  createVerificationCopyToken,
  parseVerificationCopyToken
} from '../src/modules/email/email.verification-copy';
import { embedInlineAssetsForPreview } from '../src/modules/email/templates/email-assets';
import { escapeHtml, formatDayLabel } from '../src/modules/email/templates/layout';
import {
  buildEmailMessage,
  listEmailTemplateMetadata,
  previewEmailTemplate
} from '../src/modules/email/templates';

function runTemplateTests(): void {
  const welcome = buildEmailMessage('welcome', {
    name: 'Agus',
    mail: 'agus@example.com'
  });
  assert.equal(welcome.to, 'agus@example.com');
  assert.equal(welcome.toName, 'Agus');
  assert.match(welcome.subject, /E-VIDENTE/);
  assert.match(welcome.subject, /Bienvenido\/a/);
  assert.match(welcome.textContent, /Agus/);
  assert.match(welcome.textContent, /Confirmaste tu mail correctamente/);
  assert.doesNotMatch(welcome.textContent, /código de verificación/i);
  assert.match(welcome.htmlContent, /Agus/);
  assert.match(welcome.htmlContent, /#42785e/i);
  assert.match(welcome.htmlContent, /Rubik/i);
  assert.match(welcome.htmlContent, /E-VIDENTE/);
  assert.match(welcome.htmlContent, /Mail verificado/);
  assert.match(welcome.htmlContent, /Tu cuenta est/);
  assert.doesNotMatch(welcome.htmlContent, /843184/);
  assert.doesNotMatch(welcome.htmlContent, /<script/i);

  const escaped = escapeHtml(`<Agus> "test" & 'ok'`);
  assert.equal(escaped, '&lt;Agus&gt; &quot;test&quot; &amp; &#39;ok&#39;');

  assert.equal(formatDayLabel(1), 'día');
  assert.equal(formatDayLabel(3), 'días');

  const atRisk = previewEmailTemplate('streak_at_risk', {
    name: 'Margo',
    streak_count: 4
  });
  assert.match(atRisk.subject, /sigue en juego/i);
  assert.match(atRisk.textContent, /4 días/);
  assert.match(atRisk.textContent, /desactivar los recordatorios/i);
  assert.match(atRisk.htmlContent, /desactivar los recordatorios/i);

  const lost = previewEmailTemplate('streak_lost', { streak_count: 1 });
  assert.match(lost.textContent, /1 día/);
  assert.match(lost.textContent, /volvió a cero/i);

  const metadata = listEmailTemplateMetadata();
  assert.equal(metadata.length, 5);
  assert.deepEqual(
    metadata.map((item) => item.key).sort(),
    ['email_verification', 'mail_changed', 'streak_at_risk', 'streak_lost', 'welcome']
  );

  const verify = buildEmailMessage('email_verification', {
    name: 'Agus',
    mail: 'agus@example.com',
    code: '843184',
    expiresMinutes: 15
  });
  assert.match(verify.subject, /843184/);
  assert.match(verify.textContent, /843184/);
  assert.doesNotMatch(verify.htmlContent, /843 184/);
  assert.match(verify.htmlContent, /843184/);
  assert.match(verify.htmlContent, /sin espacios|asunto/i);
  assert.doesNotMatch(verify.htmlContent, /letter-spacing: 0\.35em/);
  assert.doesNotMatch(verify.htmlContent, /Seleccioná y copiá estos 6 números/);
  assert.doesNotMatch(verify.htmlContent, /Copiar código/);
  assert.doesNotMatch(verify.textContent, /localhost/i);
  const welcomeHtml = embedInlineAssetsForPreview(welcome.htmlContent);
  assert.match(welcomeHtml, /data:image\/png;base64,|public\/email\/assets\/icons\//);
  assert.doesNotMatch(welcome.htmlContent, /cid:ev-icon-/);
  assert.match(welcome.htmlContent, /public\/email\/assets\/icons\/play\.png/);
  assert.doesNotMatch(welcome.htmlContent, /data:image\/svg\+xml/i);
  assert.doesNotMatch(welcome.htmlContent, /🔥|🎉|🔐|🔒|💪|⏱/u);
  assert.doesNotMatch(atRisk.subject, /🔥/u);

  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const token = createVerificationCopyToken('843184', expiresAt);
  assert.ok(token);
  assert.equal(parseVerificationCopyToken(token!)?.code, '843184');

  console.log('email templates unit test passed');
}

runTemplateTests();
