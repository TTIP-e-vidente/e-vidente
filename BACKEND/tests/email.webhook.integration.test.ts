import assert from 'assert/strict';
import { pool } from '../src/config/database';
import * as emailRepository from '../src/modules/email/email.repository';
import { handleBrevoWebhookEvents } from '../src/modules/email/email.webhook.service';

async function run(): Promise<void> {
  const suffix = String(Date.now());
  const mail = `webhook_${suffix}@test.com`;
  let userId = '';

  try {
    const userResult = await pool.query<{ id: string }>(
      `
        INSERT INTO users (
          username,
          name,
          display_name,
          mail,
          email_notifications_enabled,
          mail_verified_at
        )
        VALUES ($1, $2, $2, $3, true, now())
        RETURNING id;
      `,
      [`webhook_user_${suffix}`, 'Webhook User', mail]
    );
    userId = userResult.rows[0].id;

    const client = await pool.connect();
    let deliveryId = '';
    try {
      await client.query('BEGIN');
      deliveryId =
        (await emailRepository.acquireDeliverySlot(client, {
          userId,
          templateKey: 'email_verification',
          dedupeKey: `verify:${userId}:test`,
          recipientEmail: mail,
          subject: 'Código E-VIDENTE: 123456'
        })) ?? '';
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    assert.ok(deliveryId, 'delivery slot created');
    const providerMessageId = `msg-${suffix}`;
    await emailRepository.markDeliverySent(deliveryId, providerMessageId);

    const webhookResult = await handleBrevoWebhookEvents([
      {
        event: 'hard_bounce',
        email: mail,
        'message-id': `<${providerMessageId}>`,
        reason: 'Mailbox not found'
      }
    ]);

    assert.equal(webhookResult.processed, 1);
    assert.equal(webhookResult.suppressed, 1);
    assert.equal(webhookResult.deliveries_updated, 1);

    const delivery = await emailRepository.findLatestDeliveryForUser(userId, 'email_verification');
    assert.equal(delivery?.status, 'failed');
    assert.match(delivery?.error_message ?? '', /hard_bounce/i);

    const notifications = await pool.query<{ email_notifications_enabled: boolean }>(
      'SELECT email_notifications_enabled FROM users WHERE id = $1;',
      [userId]
    );
    assert.equal(notifications.rows[0].email_notifications_enabled, false);

    console.log('email.webhook.integration.test.ts OK');
  } finally {
    if (userId) {
      await pool.query('DELETE FROM email_deliveries WHERE user_id = $1;', [userId]);
      await pool.query('DELETE FROM users WHERE id = $1;', [userId]);
    }
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
