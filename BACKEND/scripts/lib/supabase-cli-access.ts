import { execSync, type ExecSyncOptions } from 'child_process';
import { hasSupabaseAccessToken, supabaseAccessToken } from './supabase-keys-local';

export interface SupabaseProjectSummary {
  ref: string;
  name: string;
}

export type CliProjectAccess =
  | { mode: 'listed'; project: SupabaseProjectSummary }
  | { mode: 'access_token' }
  | { mode: 'none'; visible: SupabaseProjectSummary[] };

function cliExecOptions(): ExecSyncOptions {
  const token = supabaseAccessToken();
  return {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    shell: process.platform === 'win32' ? 'powershell.exe' : '/bin/sh',
    env: token ? { ...process.env, SUPABASE_ACCESS_TOKEN: token } : process.env,
  };
}

export function runSupabaseCli(command: string, cwd?: string): void {
  execSync(command, {
    cwd,
    stdio: 'inherit',
    shell: process.platform === 'win32' ? 'powershell.exe' : '/bin/sh',
    env: cliExecOptions().env,
  });
}

export function listSupabaseCliProjects(): SupabaseProjectSummary[] {
  const raw = execSync('npx supabase projects list -o json', cliExecOptions()) as string;
  const payload = JSON.parse(raw) as
    | { projects?: Array<{ ref?: string; name?: string }> }
    | Array<{ ref?: string; name?: string }>;
  const rows = Array.isArray(payload) ? payload : (payload.projects ?? []);
  return rows
    .filter((row) => typeof row.ref === 'string' && row.ref.length > 0)
    .map((row) => ({
      ref: row.ref as string,
      name: typeof row.name === 'string' ? row.name : (row.ref as string),
    }));
}

export function resolveCliProjectAccess(projectRef: string): CliProjectAccess {
  if (hasSupabaseAccessToken()) {
    return { mode: 'access_token' };
  }

  const projects = listSupabaseCliProjects();
  const match = projects.find((project) => project.ref === projectRef);
  if (match) {
    return { mode: 'listed', project: match };
  }
  return { mode: 'none', visible: projects };
}

export function verifySupabaseCliProjectAccess(projectRef: string): SupabaseProjectSummary {
  const access = resolveCliProjectAccess(projectRef);
  if (access.mode === 'listed') {
    return access.project;
  }
  if (access.mode === 'access_token') {
    return { ref: projectRef, name: 'EVIDENTE (access token)' };
  }

  const visible = access.visible.map((p) => `${p.name} (${p.ref})`).join(', ') || '(ninguno)';
  throw new Error(
    `CLI sin acceso a ${projectRef}. Proyectos visibles: ${visible}.\n` +
      'Opciones:\n' +
      '  A) npx supabase logout && npx supabase login (cuenta del dashboard EVIDENTE)\n' +
      '  B) Dashboard → Account → Access Tokens → crear token del proyecto EVIDENTE\n' +
      '     Pegarlo en .env.supabase-keys.local como SUPABASE_ACCESS_TOKEN=sbp_...\n' +
      '     Luego: npm run configure:supabase-keys && npm run supabase:functions:deploy\n' +
      '  C) Deploy manual: Dashboard → Edge Functions → Deploy via CLI (instrucciones)',
  );
}

export function linkSupabaseProject(projectRef: string, repoRoot: string): void {
  runSupabaseCli(`npx supabase link --project-ref ${projectRef}`, repoRoot);
}

export function printCliAccessHint(access: CliProjectAccess, projectRef: string): void {
  if (access.mode === 'access_token') {
    console.log(
      `▶ Usando SUPABASE_ACCESS_TOKEN para ${projectRef} (sin depender del login interactivo)`,
    );
    return;
  }
  if (access.mode === 'listed') {
    console.log(`▶ CLI OK — proyecto ${access.project.name} (${access.project.ref})`);
  }
}
