import assert from 'assert/strict';
import { AddressInfo } from 'net';
import { app } from '../src/app';
import { pool } from '../src/config/database';
import { emailConfig } from '../src/modules/email/email.config';
import * as emailRepository from '../src/modules/email/email.repository';

type JsonObject = Record<string, unknown>;

async function requestJson(
  baseUrl: string,
  path: string,
  options: RequestInit = {}
): Promise<{ status: number; body: JsonObject }> {
  const response = await fetch(`${baseUrl}${path}`, options);
  const text = await response.text();
  return {
    status: response.status,
    body: text ? (JSON.parse(text) as JsonObject) : {}
  };
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = String(Date.now());
  const username = `internal_email_${suffix}`;
  const mail = `${username}@test.com`;
  let userId = '';

  try {
    const unauthorized = await requestJson(baseUrl, '/internal/email/deliveries');
    assert.equal(unauthorized.status, 401);

    const userResult = await pool.query<{ id: string }>(
      `
        INSERT INTO users (username, name, display_name, mail, email_notifications_enabled)
        VALUES ($1, $2, $2, $3, true)
        RETURNING id;
      `,
      [username, 'Internal Email User', mail]
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
          dedupeKey: `verify:${userId}:internal`,
          recipientEmail: mail,
          subject: 'Código E-VIDENTE: 111111'
        })) ?? '';
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    await emailRepository.markDeliveryFailed(deliveryId, 'Simulated send failure');

    const headers = {
      'X-Job-Secret': emailConfig.cronSecret
    };

    const byMail = await requestJson(
      baseUrl,
      `/internal/email/deliveries?mail=${encodeURIComponent(mail)}&template_key=email_verification`,
      { headers }
    );
    assert.equal(byMail.status, 200);
    assert.equal((byMail.body.lookup as JsonObject).username, username);

    const summary = byMail.body.summary as JsonObject;
    assert.equal(summary.failed, 1);
    assert.equal(byMail.body.count, 1);

    const verification = byMail.body.verification as JsonObject;
    assert.equal(verification.required, true);

    const byUsername = await requestJson(
      baseUrl,
      `/internal/email/deliveries?username=${encodeURIComponent(username)}`,
      { headers }
    );
    assert.equal(byUsername.status, 200);
    assert.equal(byUsername.body.count, 1);

    console.log('email.internal.integration.test.ts OK');
  } finally {
    if (userId) {
      await pool.query('DELETE FROM email_deliveries WHERE user_id = $1;', [userId]);
      await pool.query('DELETE FROM users WHERE id = $1;', [userId]);
    }
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
