/**
 * Diagnóstico de red/DNS y conexión Supabase.
 *
 * Uso: npm run supabase:diagnose
 */
import path from 'path';
import { BACKEND_ROOT, loadPostgresEnv } from './lib/postgres-env';
import {
  buildSupabaseConnectionTargets,
  diagnoseHostDns,
  ensureSupabaseConnection,
  extractSupabaseProjectRef,
} from './lib/supabase-connect';
import { detectSupabaseHostKind } from './lib/supabase-env';

async function main(): Promise<void> {
  const staging = loadPostgresEnv('staging');
  const envPath = path.resolve(BACKEND_ROOT, staging.envFile);

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Diagnóstico Supabase');
  console.log('═══════════════════════════════════════════\n');

  const projectRef = extractSupabaseProjectRef();
  console.log(`Project ref: ${projectRef ?? '(no detectado)'}`);
  console.log(`Host actual: ${process.env.POSTGRES_HOST} (${detectSupabaseHostKind(process.env.POSTGRES_HOST)})`);
  console.log(`User actual: ${process.env.POSTGRES_USER}\n`);

  const targets = buildSupabaseConnectionTargets();
  console.log('DNS:');
  const hostsSeen = new Set<string>();
  for (const target of targets) {
    if (hostsSeen.has(target.host)) {
      continue;
    }
    hostsSeen.add(target.host);
    const dnsInfo = await diagnoseHostDns(target.host);
    console.log(`  ${target.host} → ${dnsInfo}`);
  }

  console.log('\nConexión:');
  try {
    const result = await ensureSupabaseConnection({
      envPath,
      persistToEnvFile: true,
      silent: false,
    });
    console.log(`\nDiagnóstico OK — conectado via ${result.target.label}`);
  } catch (error) {
    console.error(`\n${(error as Error).message}`);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('\nDiagnóstico falló:', error);
  process.exit(1);
});
