/**
 * Verifica que los templates Edge estén sincronizados con BACKEND.
 * Ejecuta sync y falla si hay diff pendiente (anti-drift en CI).
 */
const { execSync } = require('child_process');
const path = require('path');

const BACKEND_ROOT = path.join(__dirname, '..');
const REPO_ROOT = path.join(BACKEND_ROOT, '..');
const EDGE_EMAIL_DIR = 'supabase/functions/_shared/email';

execSync('node scripts/sync-email-templates-edge.cjs', {
  cwd: BACKEND_ROOT,
  stdio: 'inherit',
});

try {
  execSync(`git diff --exit-code -- ${EDGE_EMAIL_DIR}`, {
    cwd: REPO_ROOT,
    stdio: 'inherit',
  });
} catch {
  console.error(
    `\n[check-email-templates-edge] ${EDGE_EMAIL_DIR} está desactualizado.\n` +
      'Ejecutá: cd BACKEND && npm run sync:email-templates:edge\n',
  );
  process.exit(1);
}

console.log('[check-email-templates-edge] OK — templates Edge en sync con BACKEND');
