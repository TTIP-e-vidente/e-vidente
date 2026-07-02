/**
 * Mail "cuenta verificada" (template account_verified):
 *  - El template existe y es distinto del welcome.
 *  - El slot de delivery con dedupe account_verified:{userId} no se duplica
 *    aunque se intente encolar dos veces (pending o sent).
 */
import assert from 'assert/strict';
import { pool } from '../src/config/database';
import { buildEmailMessage } from '../src/modules/email/templates';
import * as emailRepository from '../src/modules/email/email.repository';

async function run(): Promise<void> {
  const suffix = Date.now();
  const username = `acct_verified_${suffix}`;
  const mail = `acct_verified_${suffix}@test.com`;
  let userId = '';

  try {
    const userResult = await pool.query<{ id: string }>(
      `
        INSERT INTO users (username, name, display_name, mail, mail_verified_at)
        VALUES ($1, $2, $2, $3, now())
        RETURNING id;
      `,
      [username, 'Account Verified', mail]
    );
    userId = userResult.rows[0].id;

    // 1. Template distinto del welcome.
    const accountVerified = buildEmailMessage('account_verified', { name: 'Jugador', mail });
    const welcome = buildEmailMessage('welcome', { name: 'Jugador', mail });
    assert.equal(accountVerified.subject, 'Tu correo fue verificado');
    assert.notEqual(accountVerified.subject, welcome.subject);
    assert.ok(accountVerified.textContent.includes('Tu correo fue verificado'));
    assert.ok(accountVerified.textContent.includes('activa'));

    const dedupeKey = `account_verified:${userId}`;

    // 2. Primer encolado crea el slot pending.
    const client = await pool.connect();
    let firstId: string | null = null;
    let secondId: string | null = null;
    try {
      await client.query('BEGIN');
      firstId = await emailRepository.acquireDeliverySlot(client, {
        userId,
        templateKey: 'account_verified',
        dedupeKey,
        recipientEmail: mail,
        subject: accountVerified.subject
      });
      await client.query('COMMIT');

      await client.query('BEGIN');
      secondId = await emailRepository.acquireDeliverySlot(client, {
        userId,
        templateKey: 'account_verified',
        dedupeKey,
        recipientEmail: mail,
        subject: accountVerified.subject
      });
      await client.query('COMMIT');
    } finally {
      client.release();
    }

    assert.ok(firstId, 'el primer encolado debe crear un delivery');
    assert.equal(secondId, null, 'el segundo encolado debe deduplicarse (pending)');

    // 3. Tras marcarlo enviado tampoco se re-encola.
    await emailRepository.markDeliverySent(firstId as string, 'msg-test-account-verified');
    const client2 = await pool.connect();
    let thirdId: string | null = null;
    try {
      await client2.query('BEGIN');
      thirdId = await emailRepository.acquireDeliverySlot(client2, {
        userId,
        templateKey: 'account_verified',
        dedupeKey,
        recipientEmail: mail,
        subject: accountVerified.subject
      });
      await client2.query('COMMIT');
    } finally {
      client2.release();
    }
    assert.equal(thirdId, null, 'un delivery ya enviado nunca se re-encola');

    const rows = await pool.query<{ status: string }>(
      `
        SELECT status FROM email_deliveries
        WHERE user_id = $1 AND template_key = 'account_verified';
      `,
      [userId]
    );
    assert.equal(rows.rowCount, 1, 'debe existir exactamente un delivery account_verified');
    assert.equal(rows.rows[0].status, 'sent');

    console.log('email account-verified integration test passed');
  } finally {
    if (userId) {
      await pool.query('DELETE FROM email_deliveries WHERE user_id = $1;', [userId]);
      await pool.query('DELETE FROM users WHERE id = $1;', [userId]);
    }
  }
}

run().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
