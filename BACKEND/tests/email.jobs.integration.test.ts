import assert from 'assert/strict';
import { PoolClient } from 'pg';
import { pool } from '../src/config/database';
import { getTodayInConfiguredTimezone } from '../src/modules/email/email.service';
import * as emailRepository from '../src/modules/email/email.repository';
import * as profileRepository from '../src/modules/profile/profile.repository';
import * as streakRepository from '../src/modules/streak/streak.repository';

function shiftDateIso(dateIso: string, dayDelta: number): string {
  const anchor = new Date(`${dateIso}T12:00:00.000Z`);
  anchor.setUTCDate(anchor.getUTCDate() + dayDelta);
  return anchor.toISOString().slice(0, 10);
}

async function createUserWithStreak(
  client: PoolClient,
  suffix: string,
  options: {
    mail: string;
    emailNotificationsEnabled: boolean;
    currentCount: number;
    lastActivityDay: string;
  }
): Promise<{ userId: string; streakId: string }> {
  const username = `email_job_${suffix}`;
  const userResult = await client.query<{ id: string }>(
    `
      INSERT INTO users (
        username,
        name,
        display_name,
        mail,
        email_notifications_enabled
      )
      VALUES ($1, $2, $2, $3, $4)
      RETURNING id;
    `,
    [username, `Email Job ${suffix}`, options.mail, options.emailNotificationsEnabled]
  );
  const userId = userResult.rows[0].id;
  const profile = await profileRepository.ensureProfile(client, userId, 'CELIAQUIA');
  await streakRepository.ensureStreak(client, userId, profile.id);
  const streakResult = await client.query<{ id: string }>(
    `
      SELECT s.id
      FROM streaks s
      JOIN profiles p ON p.streak_id = s.id
      WHERE p.user_id = $1;
    `,
    [userId]
  );
  const streakId = streakResult.rows[0].id;
  await client.query(
    `
      UPDATE streaks
      SET
        current_count = $2,
        best_count = GREATEST(best_count, $2),
        last_activity_day = $3::date,
        updated_at = now()
      WHERE id = $1;
    `,
    [streakId, options.currentCount, options.lastActivityDay]
  );
  return { userId, streakId };
}

async function cleanupUser(userId: string): Promise<void> {
  await pool.query('DELETE FROM email_deliveries WHERE user_id = $1;', [userId]);
  await pool.query('DELETE FROM users WHERE id = $1;', [userId]);
}

async function run(): Promise<void> {
  const suffix = String(Date.now());
  const today = getTodayInConfiguredTimezone();
  const yesterday = shiftDateIso(today, -1);
  const threeDaysAgo = shiftDateIso(today, -3);
  const client = await pool.connect();

  let atRiskUserId = '';
  let optOutUserId = '';
  let lostUserId = '';
  let dedupeUserId = '';

  try {
    await client.query('BEGIN');
    const atRisk = await createUserWithStreak(client, `${suffix}_at_risk`, {
      mail: `at_risk_${suffix}@test.com`,
      emailNotificationsEnabled: true,
      currentCount: 4,
      lastActivityDay: yesterday
    });
    atRiskUserId = atRisk.userId;

    const optOut = await createUserWithStreak(client, `${suffix}_opt_out`, {
      mail: `opt_out_${suffix}@test.com`,
      emailNotificationsEnabled: false,
      currentCount: 4,
      lastActivityDay: yesterday
    });
    optOutUserId = optOut.userId;

    const lost = await createUserWithStreak(client, `${suffix}_lost`, {
      mail: `lost_${suffix}@test.com`,
      emailNotificationsEnabled: true,
      currentCount: 8,
      lastActivityDay: threeDaysAgo
    });
    lostUserId = lost.userId;

    const dedupe = await createUserWithStreak(client, `${suffix}_dedupe`, {
      mail: `dedupe_${suffix}@test.com`,
      emailNotificationsEnabled: true,
      currentCount: 2,
      lastActivityDay: yesterday
    });
    dedupeUserId = dedupe.userId;

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  try {
    const atRiskCandidates = await emailRepository.findStreakAtRiskCandidates(today);
    assert.ok(
      atRiskCandidates.some((row) => row.userId === atRiskUserId),
      'Usuario con racha en riesgo debe ser candidato'
    );
    assert.ok(
      !atRiskCandidates.some((row) => row.userId === optOutUserId),
      'Usuario sin consentimiento no debe ser candidato'
    );

    const dedupeClient = await pool.connect();
    let firstDeliveryId = '';
    try {
      await dedupeClient.query('BEGIN');
      firstDeliveryId =
        (await emailRepository.acquireDeliverySlot(dedupeClient, {
          userId: dedupeUserId,
          templateKey: 'streak_at_risk',
          dedupeKey: `at_risk:${today}`,
          recipientEmail: `dedupe_${suffix}@test.com`,
          subject: 'Test dedupe'
        })) ?? '';
      assert.ok(firstDeliveryId, 'Primer acquireDeliverySlot debe crear pending');
      const duplicateSlot = await emailRepository.acquireDeliverySlot(dedupeClient, {
        userId: dedupeUserId,
        templateKey: 'streak_at_risk',
        dedupeKey: `at_risk:${today}`,
        recipientEmail: `dedupe_${suffix}@test.com`,
        subject: 'Test dedupe'
      });
      assert.equal(duplicateSlot, null, 'Segundo acquire con pending debe omitir');
      await dedupeClient.query('COMMIT');
    } finally {
      dedupeClient.release();
    }

    await emailRepository.markDeliverySent(firstDeliveryId, 'test-provider-id');
    const atRiskAfterSent = await emailRepository.findStreakAtRiskCandidates(today);
    assert.ok(
      !atRiskAfterSent.some((row) => row.userId === dedupeUserId),
      'Candidato con delivery sent no debe repetirse'
    );

    const lostCandidates = await emailRepository.findStreakLostCandidates(today);
    assert.ok(
      lostCandidates.some((row) => row.userId === lostUserId),
      'Usuario con 3 días sin actividad debe ser candidato streak_lost'
    );

    const reconciled = await emailRepository.reconcileExpiredStreaksInDatabase(today);
    assert.ok(reconciled >= 1, 'Reconcile debe resetear al menos una racha vencida');

    const lostCount = await pool.query<{ current_count: number }>(
      `
        SELECT s.current_count
        FROM streaks s
        JOIN profiles p ON p.streak_id = s.id
        WHERE p.user_id = $1;
      `,
      [lostUserId]
    );
    assert.equal(lostCount.rows[0].current_count, 0, 'Racha vencida debe quedar en 0');

    const atRiskStillActive = await pool.query<{ current_count: number }>(
      `
        SELECT s.current_count
        FROM streaks s
        JOIN profiles p ON p.streak_id = s.id
        WHERE p.user_id = $1;
      `,
      [atRiskUserId]
    );
    assert.equal(
      atRiskStillActive.rows[0].current_count,
      4,
      'Racha en riesgo (ayer) no debe resetearse en reconcile'
    );

    console.log('email.jobs.integration.test.ts OK');
  } finally {
    await cleanupUser(atRiskUserId);
    await cleanupUser(optOutUserId);
    await cleanupUser(lostUserId);
    await cleanupUser(dedupeUserId);
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
