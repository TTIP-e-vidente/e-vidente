/**
 * Login con mail sin verificar:
 *  - /auth/login devuelve 403 EMAIL_NOT_VERIFIED + verification_token acotado.
 *  - El token acotado NO sirve para /auth/me, pero SÍ para email-status y
 *    verify-email/confirm.
 *  - Confirmar el OTP devuelve un accessToken completo y desbloquea el login.
 */
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
  const username = `unverified_${suffix}`;
  const mail = `unverified_${suffix}@test.com`;
  const password = 'Password123';

  try {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2;', [username, mail]);

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Unverified User',
        mail,
        password,
        birth_date: '2000-06-15'
      })
    });
    assert.equal(registerResponse.status, 201);
    const userId = getString((registerResponse.body.user as JsonObject).id);

    // 1. Login bloqueado con token acotado.
    const blockedLogin = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username, password })
    });
    assert.equal(blockedLogin.status, 403);
    assert.equal(blockedLogin.body.code, 'EMAIL_NOT_VERIFIED');
    assert.ok(blockedLogin.body.user, 'la respuesta 403 debe incluir el user');
    assert.ok(blockedLogin.body.verification, 'la respuesta 403 debe incluir verification');
    const verificationToken = getString(blockedLogin.body.verification_token);

    // Credenciales inválidas NO deben filtrar la existencia del usuario.
    const wrongPassword = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username, password: 'WrongPassword123' })
    });
    assert.equal(wrongPassword.status, 401);
    assert.equal(wrongPassword.body.code, 'INVALID_CREDENTIALS');

    // 2. El token acotado no habilita el resto de la API.
    const meWithScoped = await requestJson(baseUrl, '/auth/me', {
      method: 'GET',
      headers: { Authorization: `Bearer ${verificationToken}` }
    });
    assert.equal(meWithScoped.status, 401);

    const progressWithScoped = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers: { Authorization: `Bearer ${verificationToken}` }
    });
    assert.equal(progressWithScoped.status, 401);

    // 3. Pero sí habilita el estado de verificación.
    const emailStatus = await requestJson(baseUrl, '/player/me/email-status', {
      method: 'GET',
      headers: { Authorization: `Bearer ${verificationToken}` }
    });
    assert.equal(emailStatus.status, 200);
    assert.equal(emailStatus.body.mail, mail);

    // 4. Confirmar el OTP con el token acotado. En test no hay Brevo, así que
    // el código se inserta directo en la DB con su hash SHA-256.
    const code = '123456';
    const codeHash = crypto.createHash('sha256').update(code).digest('hex');
    await pool.query(
      'UPDATE email_verification_codes SET used_at = now() WHERE user_id = $1 AND used_at IS NULL;',
      [userId]
    );
    await pool.query(
      `
        INSERT INTO email_verification_codes (user_id, code_hash, target_mail, expires_at)
        VALUES ($1, $2, $3, now() + INTERVAL '15 minutes');
      `,
      [userId, codeHash, mail]
    );

    const confirmResponse = await requestJson(baseUrl, '/player/verify-email/confirm', {
      method: 'POST',
      headers: { Authorization: `Bearer ${verificationToken}` },
      body: JSON.stringify({ code })
    });
    assert.equal(confirmResponse.status, 200);
    assert.equal(confirmResponse.body.status, 'verified');
    const fullToken = getString(confirmResponse.body.accessToken);

    // 5. El accessToken del confirm es una sesión completa.
    const meWithFull = await requestJson(baseUrl, '/auth/me', {
      method: 'GET',
      headers: { Authorization: `Bearer ${fullToken}` }
    });
    assert.equal(meWithFull.status, 200);
    assert.equal((meWithFull.body.user as JsonObject).username, username);
    assert.ok((meWithFull.body.user as JsonObject).mail_verified_at);

    // 6. El login ahora funciona normalmente.
    const unlockedLogin = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username, password })
    });
    assert.equal(unlockedLogin.status, 200);
    assert.equal(typeof unlockedLogin.body.accessToken, 'string');

    console.log('auth login-unverified integration test passed');
  } finally {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2;', [username, mail]);
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
