/** Diagnóstico breve de verify-email-health (no imprime secrets). */
import { loadStagingWithKeys } from './lib/supabase-keys-local';
import {
  resolveSupabaseClientApiKey,
  resolveSupabaseFunctionsUrl,
} from './lib/supabase-functions-env';

async function main(): Promise<void> {
  loadStagingWithKeys();
  const baseUrl = resolveSupabaseFunctionsUrl();
  const anonKey = resolveSupabaseClientApiKey();
  const response = await fetch(`${baseUrl}/verify-email-health`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
  });
  const body = await response.json();
  console.log(JSON.stringify(body, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
