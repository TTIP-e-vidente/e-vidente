/**
 * Avatar (Express legacy, misma validación que la Edge Function):
 *  - Rechaza MIME no soportado (AVATAR_UNSUPPORTED_MIME).
 *  - Rechaza imágenes de más de 3 MB (AVATAR_TOO_LARGE).
 *  - Guarda y recupera el avatar; delete lo elimina.
 */
import assert from 'assert/strict';
import { AddressInfo } from 'net';
import { app } from '../src/app';
import { pool } from '../src/config/database';

type JsonObject = Record<string, unknown>;

// PNG válido de 1x1 px.
const TINY_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

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

async function run(): Promise<void> {
  const server = app.listen(0);
  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const suffix = Date.now();
  const username = `avatar_${suffix}`;
  const mail = `avatar_${suffix}@test.com`;
  const password = 'Password123';

  try {
    await pool.query('DELETE FROM users WHERE username = $1 OR mail = $2;', [username, mail]);

    const registerResponse = await requestJson(baseUrl, '/auth/register', {
      method: 'POST',
      body: JSON.stringify({ username, name: 'Avatar User', mail, password })
    });
    assert.equal(registerResponse.status, 201);
    const token = String(registerResponse.body.accessToken);
    const headers = { Authorization: `Bearer ${token}` };
    const userId = String((registerResponse.body.user as JsonObject).id);

    // 1. MIME no soportado.
    const badMime = await requestJson(baseUrl, '/player/me/avatar', {
      method: 'POST',
      headers,
      body: JSON.stringify({ data: TINY_PNG_BASE64, mimeType: 'image/gif' })
    });
    assert.equal(badMime.status, 400);
    assert.equal(badMime.body.code, 'AVATAR_UNSUPPORTED_MIME');

    // 2. Payload demasiado grande (> 4 MB de base64 ≈ 3 MB de imagen).
    const hugeData = 'A'.repeat(4 * 1024 * 1024 + 1);
    const tooLarge = await requestJson(baseUrl, '/player/me/avatar', {
      method: 'POST',
      headers,
      body: JSON.stringify({ data: hugeData, mimeType: 'image/png' })
    });
    // Express puede cortar antes por el body-parser limit (413 sin código propio);
    // si llega al controller, el código debe ser AVATAR_TOO_LARGE.
    assert.equal(tooLarge.status, 413);
    if (tooLarge.body.code) {
      assert.equal(tooLarge.body.code, 'AVATAR_TOO_LARGE');
    }

    // 3. Subida válida.
    const upload = await requestJson(baseUrl, '/player/me/avatar', {
      method: 'POST',
      headers,
      body: JSON.stringify({ data: TINY_PNG_BASE64, mimeType: 'image/png' })
    });
    assert.equal(upload.status, 200);
    assert.ok(upload.body.updatedAt, 'debe devolver updatedAt para cache busting');

    // 4. Descarga autenticada y pública.
    const download = await requestJson(baseUrl, '/player/me/avatar', {
      method: 'GET',
      headers
    });
    assert.equal(download.status, 200);
    assert.equal(download.body.data, TINY_PNG_BASE64);
    assert.equal(download.body.mimeType, 'image/png');

    const publicDownload = await requestJson(baseUrl, `/player/users/${userId}/avatar`, {
      method: 'GET'
    });
    assert.equal(publicDownload.status, 200);
    assert.equal(publicDownload.body.data, TINY_PNG_BASE64);

    // 5. Delete elimina la fila.
    const remove = await requestJson(baseUrl, '/player/me/avatar', {
      method: 'DELETE',
      headers
    });
    assert.equal(remove.status, 200);

    const afterDelete = await requestJson(baseUrl, '/player/me/avatar', {
      method: 'GET',
      headers
    });
    assert.equal(afterDelete.status, 200);
    assert.equal(afterDelete.body.data, null);

    console.log('avatar integration test passed');
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
