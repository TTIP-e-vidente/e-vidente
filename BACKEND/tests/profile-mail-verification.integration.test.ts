import assert from 'assert/strict';
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
  let body: JsonObject = {};
  try {
    body = text ? (JSON.parse(text) as JsonObject) : {};
  } catch {
    body = {};
  }

  return { status: response.status, body };
}

function getString(value: unknown): string {
  assert.equal(typeof value, 'string');
  return value as string;
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `mail_flow_${suffix}`;
  const originalMail = `mail_flow_${suffix}@test.com`;
  const updatedMail = `updated_mail_flow_${suffix}@test.com`;
  const password = 'Password123';

  try {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = ANY($2::text[]);', [
      username,
      [originalMail, updatedMail]
    ]);

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Mail Flow',
        mail: originalMail,
        password,
        birth_date: '2000-06-15'
      })
    });
    assert.equal(registerResponse.status, 201);
    const token = getString(registerResponse.body.accessToken);
    const headers = { Authorization: `Bearer ${token}` };

    const patchResponse = await requestJson(baseUrl, '/player/me', {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ mail: updatedMail })
    });
    assert.equal(patchResponse.status, 200);
    assert.equal((patchResponse.body.user as JsonObject).mail, updatedMail);

    const verification = patchResponse.body.verification as JsonObject;
    assert.ok(verification);
    assert.equal(verification.mail_changed, true);
    assert.equal(verification.target_mail, updatedMail);
    const sendStatus = String(verification.code_send_status);
    assert.ok(['sent', 'skipped', 'dev_console', 'rate_limited', 'send_failed'].includes(sendStatus));
    if (sendStatus === 'sent') {
      assert.equal(typeof verification.message, 'string');
      assert.ok(String(verification.message).includes(updatedMail));
    }

    const storedMail = await pool.query<{ mail: string }>(
      'SELECT mail FROM users WHERE username = $1;',
      [username]
    );
    assert.equal(storedMail.rows[0].mail, updatedMail);

    if (sendStatus === 'sent') {
      const pendingCode = await pool.query<{ target_mail: string }>(
        `
          SELECT target_mail
          FROM email_verification_codes
          WHERE user_id = (SELECT id FROM users WHERE username = $1)
            AND used_at IS NULL
          ORDER BY created_at DESC
          LIMIT 1;
        `,
        [username]
      );
      assert.equal(pendingCode.rowCount, 1);
      assert.equal(pendingCode.rows[0].target_mail, updatedMail);
    }

    const emailStatus = await requestJson(baseUrl, '/player/me/email-status', {
      method: 'GET',
      headers
    });
    assert.equal(emailStatus.status, 200);
    assert.equal(emailStatus.body.mail, updatedMail);
    if (sendStatus === 'sent') {
      const statusVerification = emailStatus.body.verification as JsonObject;
      assert.equal(statusVerification.pending_target_mail, updatedMail);
    }

    const staleMailRequest = await requestJson(baseUrl, '/player/verify-email/request', {
      method: 'POST',
      headers,
      body: JSON.stringify({ mail: originalMail })
    });
    assert.equal(staleMailRequest.status, 409);
    assert.equal(staleMailRequest.body.code, 'MAIL_OUT_OF_SYNC');
    assert.equal(staleMailRequest.body.mail, updatedMail);

    const matchingMailRequest = await requestJson(baseUrl, '/player/verify-email/request', {
      method: 'POST',
      headers,
      body: JSON.stringify({ mail: updatedMail })
    });
    assert.ok(
      matchingMailRequest.status === 200 ||
        matchingMailRequest.status === 429 ||
        matchingMailRequest.status === 503,
      `unexpected status ${matchingMailRequest.status}`
    );
    if (matchingMailRequest.status === 200) {
      assert.equal(matchingMailRequest.body.status, 'sent');
      assert.ok(String(matchingMailRequest.body.message).includes(updatedMail));
    }

    const implicitMailRequest = await requestJson(baseUrl, '/player/verify-email/request', {
      method: 'POST',
      headers,
      body: '{}'
    });
    assert.ok(
      implicitMailRequest.status === 200 ||
        implicitMailRequest.status === 429 ||
        implicitMailRequest.status === 503,
      `unexpected status ${implicitMailRequest.status}`
    );

    console.log('profile mail verification integration test passed');
  } finally {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = ANY($2::text[]);', [
      username,
      [originalMail, updatedMail]
    ]);
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
    await pool.end();
  }
}

run().catch(async (error) => {
  console.error(error);
  process.exit(1);
});
