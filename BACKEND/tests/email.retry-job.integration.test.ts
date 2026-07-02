/**
 * Outbox con backoff y locking cooperativo (migración 037):
 *  - markDeliveryFailed setea next_attempt_at (+10 min en el primer fallo).
 *  - findRetryableFailedDeliveries respeta next_attempt_at (no reintenta antes).
 *  - El claim marca locked_at/locked_by y no entrega la misma fila dos veces.
 *  - attempt_count >= max excluye la fila.
 */
import assert from 'assert/strict';
import { pool } from '../src/config/database';
import * as emailRepository from '../src/modules/email/email.repository';

async function acquireSlot(
  userId: string,
  dedupeKey: string,
  mail: string
): Promise<string> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const id = await emailRepository.acquireDeliverySlot(client, {
      userId,
      templateKey: 'account_verified',
      dedupeKey,
      recipientEmail: mail,
      subject: 'Tu correo fue verificado'
    });
    await client.query('COMMIT');
    assert.ok(id);
    return id as string;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function run(): Promise<void> {
  const suffix = Date.now();
  const username = `retry_job_${suffix}`;
  const mail = `retry_job_${suffix}@test.com`;
  let userId = '';

  try {
    const userResult = await pool.query<{ id: string }>(
      `
        INSERT INTO users (username, name, display_name, mail, mail_verified_at)
        VALUES ($1, $2, $2, $3, now())
        RETURNING id;
      `,
      [username, 'Retry Job', mail]
    );
    userId = userResult.rows[0].id;

    const deliveryId = await acquireSlot(userId, `account_verified:${userId}`, mail);

    // 1. Fallo → backoff de 10 minutos y lock liberado.
    await emailRepository.markDeliveryFailed(deliveryId, 'Brevo 503: boom');
    const afterFail = await pool.query<{
      status: string;
      next_attempt_at: Date | null;
      locked_at: Date | null;
      last_attempt_at: Date | null;
    }>(
      `
        SELECT status, next_attempt_at, locked_at, last_attempt_at
        FROM email_deliveries WHERE id = $1;
      `,
      [deliveryId]
    );
    assert.equal(afterFail.rows[0].status, 'failed');
    assert.ok(afterFail.rows[0].next_attempt_at, 'debe setear next_attempt_at');
    assert.ok(afterFail.rows[0].last_attempt_at, 'debe setear last_attempt_at');
    assert.equal(afterFail.rows[0].locked_at, null);
    const waitMinutes =
      (new Date(afterFail.rows[0].next_attempt_at as Date).getTime() - Date.now()) / 60000;
    assert.ok(
      waitMinutes > 8 && waitMinutes < 12,
      `primer backoff debe ser ~10 min (fue ${waitMinutes.toFixed(1)})`
    );

    // 2. Con next_attempt_at en el futuro no es candidato a retry.
    const tooEarly = await emailRepository.findRetryableFailedDeliveries({
      limit: 50,
      maxAttempts: 4,
      maxAgeHours: 48,
      lockedBy: `test-${suffix}`
    });
    assert.equal(
      tooEarly.some((c) => c.id === deliveryId),
      false,
      'no debe reintentarse antes de next_attempt_at'
    );

    // 3. Vencido el backoff, el claim lo toma y deja registro del lock.
    await pool.query(
      `UPDATE email_deliveries SET next_attempt_at = now() - INTERVAL '1 minute' WHERE id = $1;`,
      [deliveryId]
    );
    const claimed = await emailRepository.findRetryableFailedDeliveries({
      limit: 50,
      maxAttempts: 4,
      maxAgeHours: 48,
      lockedBy: `test-${suffix}`
    });
    assert.equal(
      claimed.some((c) => c.id === deliveryId),
      true,
      'vencido el backoff debe ser candidato'
    );
    const lockRow = await pool.query<{ locked_by: string | null }>(
      'SELECT locked_by FROM email_deliveries WHERE id = $1;',
      [deliveryId]
    );
    assert.equal(lockRow.rows[0].locked_by, `test-${suffix}`);

    // 4. Un segundo job no toma la fila mientras el lock esté fresco.
    const claimedAgain = await emailRepository.findRetryableFailedDeliveries({
      limit: 50,
      maxAttempts: 4,
      maxAgeHours: 48,
      lockedBy: `otro-job-${suffix}`
    });
    assert.equal(
      claimedAgain.some((c) => c.id === deliveryId),
      false,
      'una fila lockeada no debe entregarse a otro job'
    );

    // 5. attempt_count >= maxAttempts excluye la fila.
    await pool.query(
      `
        UPDATE email_deliveries
        SET attempt_count = 10, locked_at = NULL, locked_by = NULL,
            next_attempt_at = now() - INTERVAL '1 minute'
        WHERE id = $1;
      `,
      [deliveryId]
    );
    const exhausted = await emailRepository.findRetryableFailedDeliveries({
      limit: 50,
      maxAttempts: 4,
      maxAgeHours: 48,
      lockedBy: `test-${suffix}`
    });
    assert.equal(
      exhausted.some((c) => c.id === deliveryId),
      false,
      'con attempts agotados no debe reintentarse'
    );

    console.log('email retry-job integration test passed');
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
