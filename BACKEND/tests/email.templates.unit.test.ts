import assert from 'assert/strict';
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
  assert.match(welcome.textContent, /Agus/);
  assert.match(welcome.htmlContent, /Agus/);
  assert.match(welcome.htmlContent, /#42785e/i);
  assert.match(welcome.htmlContent, /Rubik/i);
  // Chequea que el HTML tenga estructura básica correcta
  assert.match(welcome.htmlContent, /E-VIDENTE/);
  assert.match(welcome.htmlContent, /Bienvenid/);
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

  console.log('email templates unit test passed');
}

runTemplateTests();
