/**
 * Orquesta migración completa local → Supabase staging.
 *
 * Uso:
 *   npm run migrate:all-to-supabase -- --dry-run
 *   npm run migrate:all-to-supabase -- --apply
 *   npm run migrate:all-to-supabase -- --apply --with-smoke
 */
import { execSync } from 'child_process';
import { BACKEND_ROOT } from './lib/postgres-env';

function run(command: string, label: string): void {
  console.log(`\n▶ ${label}`);
  execSync(command, { cwd: BACKEND_ROOT, stdio: 'inherit' });
}

function main(): void {
  const apply = process.argv.includes('--apply');
  const dryRun = process.argv.includes('--dry-run') || !apply;
  const withSmoke = process.argv.includes('--with-smoke');
  const skipSetup = process.argv.includes('--skip-setup');
  const skipData = process.argv.includes('--skip-data');

  if (apply && process.argv.includes('--dry-run')) {
    console.error('Usá solo uno: --dry-run o --apply');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════');
  console.log('  E-VIDENTE — Migración completa → Supabase');
  console.log('═══════════════════════════════════════════');
  console.log(`Modo: ${dryRun ? 'DRY-RUN' : 'APPLY'}`);

  if (!skipSetup) {
    if (dryRun) {
      console.log('\n▶ setup:supabase (solo en --apply; en dry-run se omite escritura remota)');
    } else {
      run('npm run setup:supabase', 'Paso 1/4 — Schema y migraciones');
    }
  }

  if (!skipData) {
    const dataCommand = dryRun
      ? 'npm run migrate:data-to-supabase:dry-run'
      : 'npm run migrate:data-to-supabase';
    run(dataCommand, dryRun ? 'Paso 2/4 — Preview datos' : 'Paso 2/4 — Copiar datos');
  }

  if (!dryRun) {
    run('npm run verify:supabase', 'Paso 3/4 — Verificar Supabase');
    if (withSmoke) {
      run('npm run smoke:staging', 'Paso 4/4 — Smoke staging');
    } else {
      console.log('\n▶ Paso 4/4 — Smoke omitido (agregá --with-smoke para correrlo)');
    }
  } else {
    console.log('\n▶ verify:supabase y smoke se ejecutan solo con --apply');
  }

  console.log('\nMigración orquestada completada.');
}

main();
