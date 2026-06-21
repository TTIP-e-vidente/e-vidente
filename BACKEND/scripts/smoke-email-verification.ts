import assert from 'assert/strict';
import crypto from 'crypto';
import { AddressInfo } from 'net';
import { app } from '../src/app';
import { pool } from '../src/config/database';

type JsonObject = Record<string, unknown>;

async function requestJson(
  baseUrl: string,
  path: string,
  options: RequestInit = {}
): Promise<{ status: number; body: JsonObject }> {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {})
    }
  });

  const text = await response.text();
  return {
    status: response.status,
    body: text ? (JSON.parse(text) as JsonObject) : {}
  };
}

function hashCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `verify_smoke_${suffix}`;
  const mail = `${username}@test.com`;
  const password = 'Password12345';
  const validCode = '654321';

  try {
    const register = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Verify Smoke',
        mail,
        password,
        birth_date: '2000-01-01',
        request_email_verification: true
      })
    });
    assert.equal(register.status, 201);
    const token = register.body.accessToken;
    assert.equal(typeof token, 'string');

    const requestVerify = await requestJson(baseUrl, '/player/verify-email/request', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: '{}'
    });
    assert.ok(
      requestVerify.status === 200 || requestVerify.status === 503 || requestVerify.status === 429,
      `unexpected request status ${requestVerify.status}`
    );

    const userResult = await pool.query<{ id: string }>(
      'SELECT id FROM users WHERE username = $1;',
      [username]
    );
    const userId = userResult.rows[0]?.id;
    assert.ok(userId, 'user id');

    await pool.query(
      `
        UPDATE email_verification_codes
        SET used_at = now()
        WHERE user_id = $1 AND used_at IS NULL;
      `,
      [userId]
    );
    await pool.query(
      `
        INSERT INTO email_verification_codes (
          user_id, code_hash, target_mail, expires_at, failed_attempt_count
        )
        VALUES ($1, $2, $3, now() + interval '15 minutes', 0);
      `,
      [userId, hashCode(validCode), mail]
    );

    const invalidConfirm = await requestJson(baseUrl, '/player/verify-email/confirm', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ code: '000000' })
    });
    assert.equal(invalidConfirm.status, 422);
    assert.equal(invalidConfirm.body.code, 'INVALID_CODE');
    assert.equal(typeof invalidConfirm.body.attempts_remaining, 'number');

    const validConfirm = await requestJson(baseUrl, '/player/verify-email/confirm', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ code: validCode })
    });
    assert.equal(validConfirm.status, 200);
    assert.equal(validConfirm.body.status, 'verified');

    const verifiedUser = await pool.query<{ mail_verified_at: Date | null }>(
      'SELECT mail_verified_at FROM users WHERE id = $1;',
      [userId]
    );
    assert.ok(verifiedUser.rows[0]?.mail_verified_at, 'mail_verified_at should be set');

    console.log(
      JSON.stringify(
        {
          status: 'ok',
          username,
          requestVerifyStatus: requestVerify.status,
          attemptsRemainingAfterInvalid: invalidConfirm.body.attempts_remaining
        },
        null,
        2
      )
    );
  } finally {
    server.close();
    await pool.end();
  }
}

void run().catch((error) => {
  console.error(error);
  process.exit(1);
});
