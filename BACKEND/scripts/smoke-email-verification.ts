import assert from 'assert/strict';
import crypto from 'crypto';
import { AddressInfo } from 'net';
import { app } from '../src/app';
import { pool } from '../src/config/database';
import { isEmailDeliveryConfigured } from '../src/modules/email/email.config';

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

async function logOptionalRealSend(
  mail: string,
  requestVerifyStatus: number
): Promise<void> {
  if (!process.argv.includes('--send')) {
    console.log(
      '[smoke:email-verification] SKIP envío real — usar --send y SMOKE_EMAIL_TO=tu@mail.com'
    );
    return;
  }

  const sendTo = process.env.SMOKE_EMAIL_TO?.trim() ?? '';
  if (!sendTo) {
    console.error('[smoke:email-verification] FAIL — falta SMOKE_EMAIL_TO en el entorno');
    process.exit(1);
  }

  if (!isEmailDeliveryConfigured()) {
    console.error(
      '[smoke:email-verification] FAIL — Brevo no configurado (EMAIL_ENABLED, BREVO_API_KEY, BREVO_SENDER_EMAIL)'
    );
    process.exit(1);
  }

  if (mail !== sendTo) {
    console.warn(
      `[smoke:email-verification] WARN — mail registrado (${mail}) distinto de SMOKE_EMAIL_TO (${sendTo})`
    );
  }

  if (requestVerifyStatus !== 200) {
    console.error(
      `[smoke:email-verification] FAIL — verify-email/request HTTP ${requestVerifyStatus}`
    );
    process.exit(1);
  }

  console.log(
    `[smoke:email-verification] OK — código enviado a ${mail}. Revisá la casilla (asunto «Código E-VIDENTE»).`
  );
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `verify_smoke_${suffix}`;
  const mail = process.env.SMOKE_EMAIL_TO?.trim() || `${username}@test.com`;
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

    const emailStatus = await requestJson(baseUrl, '/player/me/email-status', {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` }
    });
    assert.equal(emailStatus.status, 200);
    assert.equal(emailStatus.body.mail, mail);
    const verification = emailStatus.body.verification as JsonObject;
    assert.ok(verification);
    assert.equal(verification.required, true);
    assert.equal(typeof verification.cooldown_seconds, 'number');

    const requestVerify = await requestJson(baseUrl, '/player/verify-email/request', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: '{}'
    });
    assert.ok(
      requestVerify.status === 200 || requestVerify.status === 503 || requestVerify.status === 429,
      `unexpected request status ${requestVerify.status}`
    );

    await logOptionalRealSend(mail, requestVerify.status);

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

    const statusAfterInvalid = await requestJson(baseUrl, '/player/me/email-status', {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` }
    });
    assert.equal(statusAfterInvalid.status, 200);
    const verificationAfterInvalid = statusAfterInvalid.body.verification as JsonObject;
    assert.equal(
      verificationAfterInvalid.attempts_remaining,
      invalidConfirm.body.attempts_remaining
    );

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

    const statusVerified = await requestJson(baseUrl, '/player/me/email-status', {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` }
    });
    assert.equal(statusVerified.status, 200);
    const verificationVerified = statusVerified.body.verification as JsonObject;
    assert.equal(verificationVerified.required, false);
    assert.equal(verificationVerified.has_pending_code, false);

    console.log(
      JSON.stringify(
        {
          status: 'ok',
          username,
          mail,
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
