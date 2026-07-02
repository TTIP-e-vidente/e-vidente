/**
 * platform:doctor debe correr sin FAIL contra la DB local de tests y reportar
 * todos los subsistemas.
 */
import assert from 'assert/strict';
import { execSync } from 'child_process';
import path from 'path';

function run(): void {
  const backendRoot = path.resolve(__dirname, '..');
  const output = execSync('npx ts-node scripts/platform-doctor.ts', {
    cwd: backendRoot,
    env: process.env,
    encoding: 'utf8'
  });

  assert.ok(output.includes('PLATFORM DOCTOR'), 'debe imprimir el encabezado');
  for (const subsystem of ['db', 'env', 'email', 'storage', 'outbox', 'auth', 'avatars', 'sync']) {
    assert.ok(output.includes(subsystem), `debe reportar el subsistema ${subsystem}`);
  }
  assert.ok(!output.includes('[FAIL'), `no debe haber FAIL en la DB de tests:\n${output}`);

  console.log('platform doctor test passed');
}

run();
