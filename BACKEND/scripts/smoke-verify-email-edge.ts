/**
 * Smoke OTP por Supabase Edge: register → verify-email-request (envío real vía Brevo).
 * Uso:
 *   npm run smoke:verify-email-edge
 *   SMOKE_EMAIL_TO=tu@mail.com npm run smoke:verify-email-edge -- --send
 */
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
    console.error('[smoke:verify-email-edge] FAIL — faltan keys de Supabase');
    process.exit(1);
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
  };

  const sendReal = process.argv.includes('--send');
  const sendTo = process.env.SMOKE_EMAIL_TO?.trim() ?? '';
  const suffix = Date.now();
  const mail = sendReal && sendTo ? sendTo : `edge_verify_${suffix}@evidente.test`;
  const username = `edge_verify_${suffix}`;

  const register = await requestJson(`${baseUrl}/auth-register`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      username,
      name: 'Edge Verify Smoke',
      mail,
      password: 'Password123',
      birth_date: '2000-06-15',
      accept_email_notifications: false,
    }),
  });
  assert.equal(register.status, 201, `register HTTP ${register.status}`);
  const token = register.body.accessToken as string;
  assert.equal(typeof token, 'string');
  console.log('[smoke:verify-email-edge] OK register', { username, mail });

  const verify = await requestJson(`${baseUrl}/verify-email-request`, {
    method: 'POST',
    headers: {
      ...headers,
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({}),
  });

  if (verify.status === 429) {
    console.log('[smoke:verify-email-edge] OK rate-limit guard (429 cooldown activo)');
    return;
  }

  assert.equal(verify.status, 200, `verify-email-request HTTP ${verify.status}: ${JSON.stringify(verify.body)}`);
  const status = String(verify.body.status ?? '');
  assert.ok(
    status === 'sent' || status === 'already_verified',
    `status inesperado: ${status}`,
  );

  if (status === 'sent') {
    console.log('[smoke:verify-email-edge] OK código encolado/enviado vía Brevo', {
      mail,
      expires_minutes: verify.body.expires_minutes,
    });
    if (sendReal) {
      console.log(
        `[smoke:verify-email-edge] Revisá la casilla ${mail} (asunto «Código E-VIDENTE»).`,
      );
    }
  } else {
    console.log('[smoke:verify-email-edge] OK already_verified');
  }

  const badAuth = await requestJson(`${baseUrl}/verify-email-request`, {
    method: 'POST',
    headers: { ...headers, Authorization: 'Bearer invalid' },
    body: JSON.stringify({}),
  });
  assert.equal(badAuth.status, 401);
  console.log('[smoke:verify-email-edge] OK auth guard 401');
}

main().catch((error) => {
  console.error('[smoke:verify-email-edge] FAIL', error);
  process.exit(1);
});
