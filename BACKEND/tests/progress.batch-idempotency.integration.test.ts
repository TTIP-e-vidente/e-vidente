/**
 * Sync local-first idempotente:
 *  - clientRunId es obligatorio por ítem del batch.
 *  - Reintentar el mismo batch no duplica EXP ni sesiones (ignoredDuplicates).
 *  - La respuesta incluye synced/processed/createdSessions/ignoredDuplicates
 *    + progress y streak consolidados.
 */
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

function expFromSummary(body: JsonObject): number {
  const summary = body.progressSummary as JsonObject | null;
  assert.ok(summary, 'el batch con ítems sincronizados debe traer progressSummary');
  const profile = (summary as JsonObject).profile as JsonObject;
  return Number(profile.exp_count ?? 0);
}

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `batch_idem_${suffix}`;
  const mail = `batch_idem_${suffix}@test.com`;
  const password = 'Password123';

  try {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2;', [username, mail]);

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username,
        name: 'Batch Idem',
        mail,
        password,
        birth_date: '2000-06-15'
      })
    });
    assert.equal(registerResponse.status, 201);
    const token = String(registerResponse.body.accessToken);
    const headers = { Authorization: `Bearer ${token}` };

    const finishedAt = new Date().toISOString();
    const items = [
      {
        clientRunId: `run_test_${suffix}_a`,
        restriction: 'CELIAQUIA',
        expToAdd: 10,
        nodeId: `nodo_test_${suffix}`,
        gameType: 'quiz',
        accuracy: 90,
        score: 100,
        completed: true,
        finishedAt
      },
      {
        clientRunId: `run_test_${suffix}_b`,
        restriction: 'CELIAQUIA',
        expToAdd: 5,
        gameType: 'arrastre',
        completed: true,
        finishedAt
      }
    ];

    // 1. Primer batch: crea ambas sesiones.
    const first = await requestJson(baseUrl, '/player/me/progress/batch', {
      method: 'POST',
      headers,
      body: JSON.stringify({ items })
    });
    assert.equal(first.status, 200);
    assert.equal(first.body.synced, true);
    assert.equal(first.body.processed, 2);
    assert.equal(first.body.createdSessions, 2);
    assert.equal(first.body.ignoredDuplicates, 0);
    assert.ok(first.body.progress, 'debe incluir progress consolidado');
    assert.ok(first.body.streak, 'debe incluir streak consolidada');
    const expAfterFirst = expFromSummary(first.body);
    assert.equal(expAfterFirst, 15);

    // 2. Reintento del MISMO batch (timeout simulado): no duplica nada.
    const retry = await requestJson(baseUrl, '/player/me/progress/batch', {
      method: 'POST',
      headers,
      body: JSON.stringify({ items })
    });
    assert.equal(retry.status, 200);
    assert.equal(retry.body.synced, true);
    assert.equal(retry.body.processed, 2);
    assert.equal(retry.body.createdSessions, 0);
    assert.equal(retry.body.ignoredDuplicates, 2);
    const expAfterRetry = expFromSummary(retry.body);
    assert.equal(expAfterRetry, expAfterFirst, 'el reintento no debe duplicar EXP');

    const results = retry.body.results as JsonObject[];
    for (const result of results) {
      assert.equal(result.ok, true);
      assert.equal(result.duplicate, true);
    }

    // 3. games no tiene duplicados por clientRunId.
    const sessions = await pool.query<{ count: string }>(
      `
        SELECT COUNT(*)::text AS count
        FROM games g
        JOIN users u ON u.id = g.user_id
        WHERE u.username = $1;
      `,
      [username]
    );
    assert.equal(Number(sessions.rows[0].count), 2);

    // 4. Ítem sin clientRunId se rechaza individualmente.
    const missingId = await requestJson(baseUrl, '/player/me/progress/batch', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        items: [{ restriction: 'CELIAQUIA', expToAdd: 3, completed: true, finishedAt }]
      })
    });
    assert.equal(missingId.status, 200);
    assert.equal(missingId.body.synced, false);
    assert.equal(missingId.body.createdSessions, 0);
    const missingResults = missingId.body.results as JsonObject[];
    assert.equal(missingResults[0].ok, false);
    assert.ok(String(missingResults[0].error).includes('clientRunId'));

    console.log('progress batch idempotency integration test passed');
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
