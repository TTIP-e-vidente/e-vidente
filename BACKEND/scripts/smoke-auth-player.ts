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
  return {
    status: response.status,
    body: text ? (JSON.parse(text) as JsonObject) : {}
  };
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `smoke_user_${suffix}`;
  const mail = `smoke_user_${suffix}@test.com`;

  try {
    const register = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Smoke User',
        mail,
        password: 'Password123',
        age: 24
      })
    });
    assert.equal(register.status, 201);
    assert.equal(typeof register.body.accessToken, 'string');

    const login = await requestJson(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ usernameOrMail: username, password: 'Password123' })
    });
    assert.equal(login.status, 200);
    const token = login.body.accessToken;
    assert.equal(typeof token, 'string');

    const headers = { Authorization: `Bearer ${token}` };
    const me = await requestJson(baseUrl, '/auth/me', { method: 'GET', headers });
    assert.equal(me.status, 200);

    const saveProgress = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        clientRunId: `smoke_run_${suffix}`,
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: `smoke_node_${suffix}`,
        gameType: 'quiz',
        accuracy: 90,
        completed: true,
        score: 100
      })
    });
    assert.equal(saveProgress.status, 201);

    const progress = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    assert.equal(progress.status, 200);

    console.log(
      JSON.stringify(
        {
          status: 'ok',
          username,
          checked: ['register', 'login', 'auth/me', 'save progress', 'get progress']
        },
        null,
        2
      )
    );
  } finally {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2 OR email = $2;', [
      username,
      mail
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
