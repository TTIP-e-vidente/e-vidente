import assert from 'assert/strict';
import { AddressInfo } from 'net';
import { app } from '../src/app';
import { pool } from '../src/config/database';

type JsonObject = Record<string, unknown>;

const genericForgotPasswordMessage =
  'If an account exists for that mail, password reset instructions were generated.';

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

function assertNoPasswordHash(value: unknown): void {
  if (!value || typeof value !== 'object') {
    return;
  }

  assert.equal('password_hash' in value, false);
  for (const child of Object.values(value as JsonObject)) {
    assertNoPasswordHash(child);
  }
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `reset_user_${suffix}`;
  const mail = `reset_user_${suffix}@test.com`;
  const oldPassword = 'Password123';
  const newPassword = 'NewPassword123';

  try {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2 OR email = $2;', [
      username,
      mail
    ]);

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Reset User',
        mail,
        password: oldPassword,
        age: 24
      })
    });
    assert.equal(registerResponse.status, 201);
    assertNoPasswordHash(registerResponse.body);

    const forgotExistingResponse = await requestJson(baseUrl, '/auth/forgot-password', {
      method: 'POST',
      body: JSON.stringify({ mail })
    });
    assert.equal(forgotExistingResponse.status, 200);
    assert.equal(forgotExistingResponse.body.status, 'ok');
    assert.equal(forgotExistingResponse.body.message, genericForgotPasswordMessage);
    const resetToken = getString(forgotExistingResponse.body.devResetToken);
    assertNoPasswordHash(forgotExistingResponse.body);

    const forgotMissingResponse = await requestJson(baseUrl, '/auth/forgot-password', {
      method: 'POST',
      body: JSON.stringify({ mail: `missing_${suffix}@test.com` })
    });
    assert.equal(forgotMissingResponse.status, 200);
    assert.equal(forgotMissingResponse.body.status, 'ok');
    assert.equal(forgotMissingResponse.body.message, genericForgotPasswordMessage);
    assert.equal('devResetToken' in forgotMissingResponse.body, false);
    assertNoPasswordHash(forgotMissingResponse.body);

    const resetResponse = await requestJson(baseUrl, '/auth/reset-password', {
      method: 'POST',
      body: JSON.stringify({ token: resetToken, newPassword })
    });
    assert.equal(resetResponse.status, 200);
    assert.equal(resetResponse.body.status, 'ok');
    assert.equal(resetResponse.body.message, 'Password updated');
    assertNoPasswordHash(resetResponse.body);

    const oldPasswordLoginResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: mail, password: oldPassword })
    });
    assert.equal(oldPasswordLoginResponse.status, 401);

    const newPasswordLoginResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: mail, password: newPassword })
    });
    assert.equal(newPasswordLoginResponse.status, 200);
    assert.equal(typeof newPasswordLoginResponse.body.accessToken, 'string');
    assertNoPasswordHash(newPasswordLoginResponse.body);

    const reusedTokenResponse = await requestJson(baseUrl, '/auth/reset-password', {
      method: 'POST',
      body: JSON.stringify({ token: resetToken, newPassword: 'AnotherPassword123' })
    });
    assert.equal(reusedTokenResponse.status, 400);
    assert.equal(reusedTokenResponse.body.error, 'Invalid or expired reset token');
    assertNoPasswordHash(reusedTokenResponse.body);

    const invalidTokenResponse = await requestJson(baseUrl, '/auth/reset-password', {
      method: 'POST',
      body: JSON.stringify({ token: 'invalid-token', newPassword: 'AnotherPassword123' })
    });
    assert.equal(invalidTokenResponse.status, 400);
    assert.equal(invalidTokenResponse.body.error, 'Invalid or expired reset token');
    assertNoPasswordHash(invalidTokenResponse.body);

    const forgotForShortPasswordResponse = await requestJson(baseUrl, '/auth/forgot-password', {
      method: 'POST',
      body: JSON.stringify({ mail })
    });
    assert.equal(forgotForShortPasswordResponse.status, 200);
    const shortPasswordToken = getString(forgotForShortPasswordResponse.body.devResetToken);

    const shortPasswordResponse = await requestJson(baseUrl, '/auth/reset-password', {
      method: 'POST',
      body: JSON.stringify({ token: shortPasswordToken, newPassword: 'short' })
    });
    assert.equal(shortPasswordResponse.status, 400);
    assertNoPasswordHash(shortPasswordResponse.body);

    console.log('auth password reset integration test passed');
  } finally {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2 OR email = $2;', [
      username,
      mail
    ]);
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

run().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
