import { execSync } from 'child_process';
import path from 'path';

const backendRoot = path.resolve(__dirname, '..');

const integrationTests = [
  'tests/postgres.integration.test.ts',
  'tests/email.templates.unit.test.ts',
  'tests/email.jobs.integration.test.ts',
  'tests/email.webhook.integration.test.ts',
  'tests/email.internal.integration.test.ts',
  'tests/auth.integration.test.ts',
  'tests/player_authenticated.integration.test.ts',
  'tests/profile-mail-verification.integration.test.ts'
];

const smokeScripts = [
  'scripts/smoke-email-verification.ts'
];

function runIntegrationTests(): void {
  const env: NodeJS.ProcessEnv = {
    ...process.env,
    NODE_ENV: 'test',
    EMAIL_ENABLED: 'false',
    EMAIL_CRON_SECRET: process.env.EMAIL_CRON_SECRET ?? 'evidente_email_cron_test_secret'
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

  for (const relativeScriptPath of smokeScripts) {
    console.log(`\n> ts-node ${relativeScriptPath}`);
    execSync(`npx ts-node "${path.join(backendRoot, relativeScriptPath)}"`, {
      cwd: backendRoot,
      env,
      stdio: 'inherit'
    });
  }
}

runIntegrationTests();
