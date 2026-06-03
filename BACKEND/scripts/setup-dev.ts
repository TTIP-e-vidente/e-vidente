import { execSync, spawnSync } from 'child_process';
import dotenv from 'dotenv';
import path from 'path';
import { Pool } from 'pg';

dotenv.config();

const PROJECT_ROOT = path.resolve(__dirname, '..');

// ── Helpers ────────────────────────────────────────────────────────────────────

function step(label: string): void {
  console.log(`\n── ${label}`);
}

function run(command: string, description: string): void {
  console.log(`  > ${command}`);
  try {
    execSync(command, { cwd: PROJECT_ROOT, stdio: 'inherit' });
  } catch (error) {
    console.error(`\nERROR: "${description}" falló.`);
    console.error((error as Error).message);
    process.exit(1);
  }
}

async function waitForPostgres(maxRetries = 20, delayMs = 2000): Promise<void> {
  const pool = new Pool({
    host: process.env.POSTGRES_HOST ?? 'localhost',
    port: Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    connectionTimeoutMillis: 3000,
  });

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const client = await pool.connect();
      client.release();
      await pool.end();
      console.log('  PostgreSQL disponible.');
      return;
    } catch {
      const remaining = maxRetries - attempt;
      if (remaining === 0) {
        await pool.end();
        console.error(`\nERROR: PostgreSQL no respondió luego de ${maxRetries} intentos.`);
        console.error('Verificá que Docker esté corriendo y que el contenedor esté sano.');
        process.exit(1);
      }
      console.log(`  Esperando PostgreSQL... (intento ${attempt}/${maxRetries})`);
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

async function validateConnection(): Promise<void> {
  const pool = new Pool({
    host: process.env.POSTGRES_HOST ?? 'localhost',
    port: Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
  });

  try {
    const result = await pool.query<{ current_database: string; current_user: string }>(
      'SELECT current_database(), current_user;'
    );
    const row = result.rows[0];
    console.log(`  DB: ${row.current_database}  |  user: ${row.current_user}`);
  } finally {
    await pool.end();
  }
}

// ── Main ───────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Backend Dev Setup');
  console.log('  SOLO PARA DESARROLLO LOCAL');
  console.log('═══════════════════════════════════════════');

  // 1. Levantar PostgreSQL
  step('1/5  Levantando PostgreSQL con Docker Compose...');
  run('docker compose up -d', 'docker compose up -d');

  // 2. Esperar a que Postgres esté listo
  step('2/5  Esperando conexión con PostgreSQL...');
  await waitForPostgres();

  // 3. Migraciones
  step('3/5  Ejecutando migraciones...');
  run('npx ts-node scripts/run-migrations.ts', 'npm run migrate');

  // 4. Seed de usuarios demo
  step('4/5  Creando usuarios demo...');
  run('npx ts-node scripts/seed-dev-users.ts', 'seed-dev-users');

  // 5. Validación de conexión
  step('5/5  Validando conexión con la base...');
  await validateConnection();

  // Instrucciones finales
  console.log('\n═══════════════════════════════════════════');
  console.log('  Backend dev setup listo.');
  console.log('═══════════════════════════════════════════');
  console.log('\nUsuarios demo:');
  console.log('  - margo / 123');
  console.log('  - agus  / 123');
  console.log('\nAhora podés:');
  console.log('  1. npm run dev');
  console.log('  2. Abrir Godot');
  console.log('  3. Ir a Login.tscn (res://project/auth/Login.tscn)');
  console.log('  4. Ingresar con margo / 123 o agus / 123');
  console.log('');
}

main().catch((error) => {
  console.error('\nSetup falló:', error);
  process.exit(1);
});
