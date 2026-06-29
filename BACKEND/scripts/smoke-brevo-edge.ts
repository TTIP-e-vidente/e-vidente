/**
 * Smoke Brevo / verify-email-health en Supabase Edge.
 * Uso: npm run smoke:brevo-edge
 */
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  canUseSupabaseEmailFunctions,
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';

function fail(message: string): never {
  console.error(`[smoke:brevo-edge] FAIL — ${message}`);
  process.exit(1);
}

async function main(): Promise<void> {
  loadStagingWithKeys();
  if (!canUseSupabaseEmailFunctions()) {
    fail('faltan SUPABASE_PROJECT_REF y publishable/anon key');
  }

  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const response = await fetch(`${baseUrl}/verify-email-health`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
  });

  if (!response.ok) {
    fail(`verify-email-health HTTP ${response.status}`);
  }

  const body = (await response.json()) as {
    delivery_configured?: boolean;
    sender_email?: string | null;
    brevo_probe?: { ok?: boolean; error?: string; hint?: string; checked_at?: string };
    hints?: string[];
  };

  if (!body.delivery_configured) {
    const hints = body.hints?.join(' ') ?? body.brevo_probe?.hint ?? body.brevo_probe?.error;
    fail(hints ?? 'Brevo no configurado en Edge secrets');
  }

  console.log('[smoke:brevo-edge] OK delivery_configured', {
    sender: body.sender_email,
    probe: body.brevo_probe?.checked_at,
  });
}

main().catch((error) => {
  fail(error instanceof Error ? error.message : String(error));
});
