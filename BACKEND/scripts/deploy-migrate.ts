import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import {
  assertSupabaseStagingEnv,
  BACKEND_ROOT,
  connectSupabase,
  describeConnection,
  loadBackendEnv,
} from './lib/postgres-env';
import { isRemotePostgres } from '../src/config/postgresPoolConfig';

function resolveMigrationsRunner(): string {
  const compiled = path.join(BACKEND_ROOT, 'dist/scripts/run-migrations.js');
  if (fs.existsSync(compiled)) {
    return `node "${compiled}"`;
  }
  return 'npx ts-node scripts/run-migrations.ts';
}

async function main(): Promise<void> {
  const envFileArg = process.argv[2]?.trim();
  if (envFileArg) {
    process.env.ENV_FILE = envFileArg;
  }

  const loaded = loadBackendEnv();
  const envPath = path.resolve(BACKEND_ROOT, loaded.envFile);

  if (!fs.existsSync(envPath)) {
    console.error(`ERROR: no existe ${envPath}`);
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Deploy migrate');
  console.log('═══════════════════════════════════════════');
  console.log(`Env: ${loaded.envFile}`);
  console.log(`Target: ${describeConnection()}`);

  if (isRemotePostgres()) {
    assertSupabaseStagingEnv(envPath);
  }

  try {
    if (isRemotePostgres()) {
      const info = await connectSupabase({ envPath, persistToEnvFile: true });
      console.log(`Conexión OK — ${info.user}@${info.database}`);
      console.log(`Activo: ${describeConnection()}`);
    }
  } catch (error) {
    console.error('ERROR: no se pudo conectar a Postgres.');
    console.error((error as Error).message);
    console.error('Probá: npm run supabase:diagnose');
    process.exit(1);
  }

  execSync(resolveMigrationsRunner(), {
    cwd: BACKEND_ROOT,
    stdio: 'inherit',
    env: { ...process.env, ENV_FILE: loaded.envFile },
  });

  console.log('\nDeploy migrate completado.');
}

main().catch((error) => {
  console.error('\nDeploy migrate falló:', error);
  process.exit(1);
});
