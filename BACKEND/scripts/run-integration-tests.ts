import { execSync } from 'child_process';
import path from 'path';

const backendRoot = path.resolve(__dirname, '..');

const integrationTests = [
  'tests/postgres.integration.test.ts',
  'tests/email.templates.unit.test.ts',
  'tests/auth.integration.test.ts',
  'tests/player_authenticated.integration.test.ts'
];

function runIntegrationTests(): void {
  const env: NodeJS.ProcessEnv = {
    ...process.env,
    NODE_ENV: 'test',
    EMAIL_ENABLED: 'false'
  };

  for (const relativeTestPath of integrationTests) {
    const testPath = path.join(backendRoot, relativeTestPath);
    console.log(`\n> ts-node ${relativeTestPath}`);
    execSync(`npx ts-node "${testPath}"`, {
      cwd: backendRoot,
      env,
      stdio: 'inherit'
    });
  }
}

runIntegrationTests();
