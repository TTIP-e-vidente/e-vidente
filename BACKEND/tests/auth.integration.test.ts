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
  const username = `auth_user_${suffix}`;
  const usernameSameMail = `auth_user_same_mail_${suffix}`;
  const mail = `auth_user_${suffix}@test.com`;
  const password = 'Password123';
  const sameMailPassword = 'Password456';

  try {
    await pool.query('DELETE FROM users WHERE username = ANY($1) OR mail = $2;', [
      [username, usernameSameMail],
      mail
    ]);

    const invalidRegisterResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username: '',
        name: 'Invalid User',
        password,
        mail: `invalid_${suffix}@test.com`
      })
    });
    assert.equal(invalidRegisterResponse.status, 400);

    const shortPasswordResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username: `short_password_${suffix}`,
        name: 'Short Password',
        password: 'short',
        mail: `short_password_${suffix}@test.com`
      })
    });
    assert.equal(shortPasswordResponse.status, 400);

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Auth User',
        mail,
        password,
        birth_date: '2000-06-15',
        accept_email_notifications: false
      })
    });

    assert.equal(registerResponse.status, 201);
    assert.ok(registerResponse.body.user);
    assert.equal(typeof registerResponse.body.accessToken, 'string');
    assert.ok(registerResponse.body.verification);
    const verification = registerResponse.body.verification as JsonObject;
    assert.equal(typeof verification.code_send_status, 'string');
    assert.equal(typeof verification.message, 'string');

    const registeredUser = registerResponse.body.user as JsonObject;
    assert.equal(registeredUser.username, username);
    assert.equal(registeredUser.name, 'Auth User');
    assert.equal(registeredUser.mail, mail);
    assert.equal(registeredUser.birth_date, '2000-06-15');
    assert.equal('password_hash' in registeredUser, false);
    assert.equal('password' in registeredUser, false);

    const storedPasswordResult = await pool.query<{ password_hash: string }>(
      'SELECT password_hash FROM users WHERE username = $1;',
      [username]
    );
    assert.equal(storedPasswordResult.rowCount, 1);
    assert.notEqual(storedPasswordResult.rows[0].password_hash, password);
    assert.ok(storedPasswordResult.rows[0].password_hash.length > 20);

    const storedNotificationsResult = await pool.query<{ email_notifications_enabled: boolean }>(
      'SELECT email_notifications_enabled FROM users WHERE username = $1;',
      [username]
    );
    assert.equal(storedNotificationsResult.rowCount, 1);
    assert.equal(storedNotificationsResult.rows[0].email_notifications_enabled, false);

    const duplicateResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Auth User 2',
        mail: `duplicate_${suffix}@test.com`,
        password
      })
    });
    assert.equal(duplicateResponse.status, 409);

    const sameMailRegisterResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username: usernameSameMail,
        name: 'Auth Same Mail',
        mail,
        password: sameMailPassword,
        birth_date: '2000-06-15'
      })
    });
    assert.equal(sameMailRegisterResponse.status, 201);
    assert.equal((sameMailRegisterResponse.body.user as JsonObject).mail, mail);

    // Con mail sin verificar el login queda bloqueado (403 EMAIL_NOT_VERIFIED)
    // y entrega un token acotado que solo sirve para verificar.
    const unverifiedLoginResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username, password })
    });
    assert.equal(unverifiedLoginResponse.status, 403);
    assert.equal(unverifiedLoginResponse.body.code, 'EMAIL_NOT_VERIFIED');
    assert.equal(typeof unverifiedLoginResponse.body.verification_token, 'string');

    await pool.query('UPDATE users SET mail_verified_at = now() WHERE username = $1;', [
      username
    ]);
    await pool.query('UPDATE users SET mail_verified_at = now() WHERE username = $1;', [
      usernameSameMail
    ]);

    const loginWithUsernameResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username, password })
    });
    assert.equal(loginWithUsernameResponse.status, 200);
    assert.equal(typeof loginWithUsernameResponse.body.accessToken, 'string');
    assert.equal('password_hash' in (loginWithUsernameResponse.body.user as JsonObject), false);

    const loginWithMailResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: mail, password })
    });
    assert.equal(loginWithMailResponse.status, 200);
    assert.equal((loginWithMailResponse.body.user as JsonObject).username, username);

    const loginSameMailSecondAccountResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: mail, password: sameMailPassword })
    });
    assert.equal(loginSameMailSecondAccountResponse.status, 200);
    assert.equal(
      (loginSameMailSecondAccountResponse.body.user as JsonObject).username,
      usernameSameMail
    );

    const failedLoginResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username, password: 'WrongPassword123' })
    });
    assert.equal(failedLoginResponse.status, 401);
    assert.equal(failedLoginResponse.body.error, 'Invalid credentials');

    const missingPasswordLoginResponse = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username })
    });
    assert.equal(missingPasswordLoginResponse.status, 400);

    const token = getString(loginWithUsernameResponse.body.accessToken);
    const meResponse = await requestJson(baseUrl, '/auth/me', {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` }
    });
    assert.equal(meResponse.status, 200);
    assert.equal((meResponse.body.user as JsonObject).username, username);
    assert.equal('password_hash' in (meResponse.body.user as JsonObject), false);

    const missingTokenResponse = await requestJson(baseUrl, '/auth/me', { method: 'GET' });
    assert.equal(missingTokenResponse.status, 401);

    const invalidTokenResponse = await requestJson(baseUrl, '/auth/me', {
      method: 'GET',
      headers: { Authorization: 'Bearer invalid-token' }
    });
    assert.equal(invalidTokenResponse.status, 401);

    const logoutResponse = await requestJson(baseUrl, '/auth/logout', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` }
    });
    assert.equal(logoutResponse.status, 200);
    assert.equal(logoutResponse.body.status, 'ok');
    assert.equal(logoutResponse.body.message, 'Logout handled client-side');

    console.log('auth integration test passed');
  } finally {
    await pool.query('DELETE FROM users WHERE username = ANY($1) OR mail = $2;', [
      [username, usernameSameMail],
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
