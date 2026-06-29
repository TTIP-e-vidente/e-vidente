/**
 * Verifica acceso CLI o access token al proyecto EVIDENTE.
 * Uso: npm run supabase:cli-check
 */
import {
  listSupabaseCliProjects,
  resolveCliProjectAccess,
  printCliAccessHint,
} from './lib/supabase-cli-access';
import { assertManagementProjectAccess } from './lib/supabase-management-api';
import { hasSupabaseAccessToken, loadStagingWithKeys } from './lib/supabase-keys-local';

async function main(): Promise<void> {
  const loaded = loadStagingWithKeys();
  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim();
  if (!projectRef) {
    console.error('FAIL — Falta SUPABASE_PROJECT_REF en %s', loaded.envPath);
    console.error('  Corré: npm run configure:supabase-keys');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════');
  console.log('  Supabase CLI — acceso al proyecto');
  console.log('═══════════════════════════════════════════');
  console.log(`  Env: ${loaded.envFile}`);
  console.log(`  Ref: ${projectRef}\n`);

  if (hasSupabaseAccessToken()) {
    try {
      const project = await assertManagementProjectAccess(projectRef);
      console.log('OK  Management API — %s (%s)', project.name, project.ref);
      console.log('\nSiguiente: npm run supabase:functions:deploy\n');
      return;
    } catch (error) {
      console.error('FAIL — %s', error instanceof Error ? error.message : error);
      console.error('\nAlternativa: npm run supabase:functions:dashboard-guide\n');
      process.exit(1);
    }
  }

  const access = resolveCliProjectAccess(projectRef);
  if (access.mode === 'none') {
    console.error('FAIL — La cuenta del CLI NO ve el proyecto %s (EVIDENTE).', projectRef);
    console.error('\nProyectos visibles con el login actual:');
    for (const p of access.visible) {
      console.error('  • %s (%s)', p.name, p.ref);
    }
    console.error('\nSolución recomendada (elegí una):');
    console.error('  A) npx supabase logout && npx supabase login');
    console.error('     → misma cuenta que abre el dashboard de EVIDENTE');
    console.error('  B) Access Token (cuenta del dashboard EVIDENTE):');
    console.error('     Account → Access Tokens → sbp_...');
    console.error('     BACKEND/.env.supabase-keys.local → SUPABASE_ACCESS_TOKEN');
    console.error('     npm run configure:supabase-keys');
    console.error('  C) npm run supabase:functions:dashboard-guide\n');
    process.exit(1);
  }

  printCliAccessHint(access, projectRef);
  if (access.mode === 'listed') {
    const projects = listSupabaseCliProjects();
    console.log(`  Total proyectos visibles: ${projects.length}`);
  }
  console.log('\nSiguiente: npm run supabase:functions:deploy\n');
}

main().catch((error) => {
  console.error('FAIL —', error instanceof Error ? error.message : error);
  process.exit(1);
});
