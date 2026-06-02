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
  const username = `player_auth_${suffix}`;
  const mail = `player_auth_${suffix}@test.com`;
  const password = 'Password123';

  try {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2 OR email = $2;', [
      username,
      mail
    ]);

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Player Auth',
        mail,
        password,
        age: 24
      })
    });
    assert.equal(registerResponse.status, 201);
    const token = getString(registerResponse.body.accessToken);
    const headers = { Authorization: `Bearer ${token}` };

    const playerMeResponse = await requestJson(baseUrl, '/player/me', {
      method: 'GET',
      headers
    });
    assert.equal(playerMeResponse.status, 200);
    assert.equal((playerMeResponse.body.user as JsonObject).username, username);
    assert.equal('password_hash' in (playerMeResponse.body.user as JsonObject), false);
    assert.ok(playerMeResponse.body.profile);
    assert.ok(playerMeResponse.body.streak);

    const missingTokenResponse = await requestJson(baseUrl, '/player/me', { method: 'GET' });
    assert.equal(missingTokenResponse.status, 401);

    const missingProgressTokenResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET'
    });
    assert.equal(missingProgressTokenResponse.status, 401);

    const missingRestrictionResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ expToAdd: 10 })
    });
    assert.equal(missingRestrictionResponse.status, 400);

    const invalidRestrictionResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'PALEO', expToAdd: 10 })
    });
    assert.equal(invalidRestrictionResponse.status, 400);

    const invalidAccuracyResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify({ restriction: 'CELIAQUIA', accuracy: 120 })
    });
    assert.equal(invalidAccuracyResponse.status, 400);

    const progressPayload = {
      restriction: 'CELIAQUIA',
      expToAdd: 10,
      nodeId: `demo_node_${suffix}`,
      gameType: 'quiz',
      accuracy: 90,
      completed: true,
      score: 100
    };
    const saveProgressResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'POST',
      headers,
      body: JSON.stringify(progressPayload)
    });
    assert.equal(saveProgressResponse.status, 201);
    assert.equal((saveProgressResponse.body.user as JsonObject).username, username);

    const progressResponse = await requestJson(baseUrl, '/player/me/progress', {
      method: 'GET',
      headers
    });
    assert.equal(progressResponse.status, 200);
    assert.equal((progressResponse.body.user as JsonObject).username, username);
    assert.equal('password_hash' in (progressResponse.body.user as JsonObject), false);

    const progress = progressResponse.body.progress as JsonObject[];
    assert.equal(Array.isArray(progress), true);
    assert.equal(progress.some((row) => row.restriction_type === 'CELIAQUIA'), true);

    const completedNodes = progressResponse.body.completedNodes as JsonObject[];
    assert.equal(
      completedNodes.some((row) => row.node_id === progressPayload.nodeId),
      true
    );

    const sessions = progressResponse.body.recentGameSessions as JsonObject[];
    assert.equal(sessions.some((row) => row.node_id === progressPayload.nodeId), true);

    const storedResult = await pool.query<{
      game_sessions_count: string;
      completed_nodes_count: string;
    }>(
      `
        SELECT
          COUNT(DISTINCT gs.id)::text AS game_sessions_count,
          COUNT(DISTINCT cn.id)::text AS completed_nodes_count
        FROM users u
        LEFT JOIN game_sessions gs ON gs.user_id = u.id AND gs.node_id = $2
        LEFT JOIN completed_nodes cn ON cn.user_id = u.id AND cn.node_id = $2
        WHERE u.username = $1;
      `,
      [username, progressPayload.nodeId]
    );
    assert.equal(storedResult.rows[0].game_sessions_count, '1');
    assert.equal(storedResult.rows[0].completed_nodes_count, '1');

    console.log('player authenticated integration test passed');
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
