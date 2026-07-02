import assert from 'assert/strict';
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';

type JsonObject = Record<string, unknown>;

async function requestJson(
  url: string,
  options: RequestInit = {},
): Promise<{ status: number; body: JsonObject }> {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
  const text = await response.text();
  return {
    status: response.status,
    body: text ? (JSON.parse(text) as JsonObject) : {},
  };
}

async function main(): Promise<void> {
  loadStagingWithKeys();

  if (!canUseSupabaseEmailFunctions()) {
    console.error('[smoke:auth-edge] FAIL — falta SUPABASE_ANON_KEY o SUPABASE_PROJECT_REF');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
  };

  const health = await requestJson(`${baseUrl}/auth-health`, {
    method: 'GET',
    headers,
  });
  assert.equal(health.status, 200, `auth-health HTTP ${health.status}`);
  assert.equal(health.body.status, 'ok');
  assert.equal(health.body.remote, true);
  const migrations = health.body.migrations as JsonObject;
  assert.equal(migrations?.healthy, true, 'auth-health migrations no healthy');
  assert.equal(migrations?.expected, 37, 'auth-health expected migration count');
  console.log('[smoke:auth-edge] OK auth-health', {
    migrations,
  });

  const suffix = Date.now();
  const username = `edge_auth_${suffix}`;
  const mail = `edge_auth_${suffix}@test.com`;

  const register = await requestJson(`${baseUrl}/auth-register`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      username,
      name: 'Edge Auth Smoke',
      mail,
      password: 'Password123',
      birth_date: '2000-06-15',
      accept_email_notifications: false,
    }),
  });
  assert.equal(register.status, 201, `register HTTP ${register.status}`);
  assert.equal(typeof register.body.accessToken, 'string');
  assert.equal((register.body.user as JsonObject)?.username, username);
  console.log('[smoke:auth-edge] OK register');

  // Con mail sin verificar el login queda bloqueado y entrega un token acotado
  // que solo sirve para los endpoints de verificación.
  const blockedLogin = await requestJson(`${baseUrl}/auth-login`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      usernameOrMail: username,
      password: 'Password123',
    }),
  });
  assert.equal(blockedLogin.status, 403, `login sin verificar HTTP ${blockedLogin.status}`);
  assert.equal(blockedLogin.body.code, 'EMAIL_NOT_VERIFIED');
  const verificationToken = blockedLogin.body.verification_token as string;
  assert.equal(typeof verificationToken, 'string');
  console.log('[smoke:auth-edge] OK login bloqueado sin verificar (EMAIL_NOT_VERIFIED)');

  const statusWithScoped = await requestJson(`${baseUrl}/player-email-status`, {
    method: 'GET',
    headers: {
      ...headers,
      Authorization: `Bearer ${verificationToken}`,
    },
  });
  assert.equal(statusWithScoped.status, 200, `email-status con token acotado HTTP ${statusWithScoped.status}`);
  console.log('[smoke:auth-edge] OK token acotado habilita email-status');

  const meWithScoped = await requestJson(`${baseUrl}/auth-me`, {
    method: 'GET',
    headers: {
      ...headers,
      Authorization: `Bearer ${verificationToken}`,
    },
  });
  assert.equal(meWithScoped.status, 401, 'el token acotado no debe habilitar auth-me');
  console.log('[smoke:auth-edge] OK token acotado rechazado en auth-me');

  // Verificar el mail directo en la DB (el OTP real viaja por Brevo) y
  // comprobar que el login queda desbloqueado.
  const { pool } = await import('../src/config/database');
  await pool.query('UPDATE users SET mail_verified_at = now() WHERE username = $1;', [username]);

  const login = await requestJson(`${baseUrl}/auth-login`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      usernameOrMail: username,
      password: 'Password123',
    }),
  });
  assert.equal(login.status, 200, `login HTTP ${login.status}`);
  const token = login.body.accessToken as string;
  assert.equal(typeof token, 'string');
  console.log('[smoke:auth-edge] OK login con mail verificado');
  await pool.end();

  const me = await requestJson(`${baseUrl}/auth-me`, {
    method: 'GET',
    headers: {
      ...headers,
      Authorization: `Bearer ${token}`,
    },
  });
  assert.equal(me.status, 200, `auth-me HTTP ${me.status}`);
  assert.equal((me.body.user as JsonObject)?.username, username);
  console.log('[smoke:auth-edge] OK auth-me');

  const badLogin = await requestJson(`${baseUrl}/auth-login`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      usernameOrMail: username,
      password: 'wrong-password',
    }),
  });
  assert.equal(badLogin.status, 401, 'credenciales inválidas deben dar 401');
  console.log('[smoke:auth-edge] OK invalid credentials guard');
}

main().catch((error) => {
  console.error('[smoke:auth-edge] FAIL', error);
  process.exit(1);
});
