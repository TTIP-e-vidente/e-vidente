import { supabaseAccessToken } from './supabase-keys-local';

const MANAGEMENT_API = 'https://api.supabase.com/v1';

export interface ManagementProject {
  ref: string;
  name: string;
}

export function looksLikeWrongTokenKind(token: string): string | null {
  if (token.startsWith('sb_secret_')) {
    return 'Parece sb_secret_* (API secret del proyecto). Necesitás un Access Token sbp_* de Account → Access Tokens.';
  }
  if (token.startsWith('sb_publishable_')) {
    return 'Parece sb_publishable_* (API key). Necesitás un Access Token sbp_* de Account → Access Tokens.';
  }
  if (token.startsWith('eyJ')) {
    return 'Parece un JWT (anon/service_role). Necesitás un Access Token sbp_* de Account → Access Tokens.';
  }
  return null;
}

export async function fetchManagementProject(
  projectRef: string,
  token?: string,
): Promise<ManagementProject | null> {
  const accessToken = token?.trim() || supabaseAccessToken();
  if (!accessToken) {
    return null;
  }

  const response = await fetch(`${MANAGEMENT_API}/projects/${projectRef}`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });

  if (response.status === 404) {
    return null;
  }
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Management API HTTP ${response.status}: ${body}`);
  }

  const data = (await response.json()) as { id?: string; name?: string };
  return {
    ref: data.id ?? projectRef,
    name: data.name ?? projectRef,
  };
}

export async function listManagementProjects(token?: string): Promise<ManagementProject[]> {
  const accessToken = token?.trim() || supabaseAccessToken();
  if (!accessToken) {
    return [];
  }

  const response = await fetch(`${MANAGEMENT_API}/projects`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Management API HTTP ${response.status}: ${body}`);
  }

  const data = (await response.json()) as Array<{ id?: string; name?: string }>;
  return data
    .filter((row) => typeof row.id === 'string')
    .map((row) => ({ ref: row.id as string, name: row.name ?? row.id as string }));
}

export async function assertManagementProjectAccess(projectRef: string): Promise<ManagementProject> {
  const token = supabaseAccessToken();
  if (token) {
    const wrongKind = looksLikeWrongTokenKind(token);
    if (wrongKind) {
      throw new Error(wrongKind);
    }
  }

  try {
    const project = await fetchManagementProject(projectRef);
    if (project) {
      return project;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (message.includes('403') || message.includes('privileges') || message.includes('access-control')) {
      throw buildAccessDeniedError(projectRef, message);
    }
    throw error;
  }

  if (token) {
    let visible: ManagementProject[] = [];
    try {
      visible = await listManagementProjects();
    } catch {
      visible = [];
    }
    const names = visible.map((p) => `${p.name} (${p.ref})`).join(', ') || '(ninguno)';
    throw new Error(
      `SUPABASE_ACCESS_TOKEN no tiene acceso al proyecto ${projectRef}.\n` +
        `Proyectos visibles con ese token: ${names}\n\n` +
        'El token debe crearse estando logueado en la cuenta que VE EVIDENTE en el dashboard:\n' +
        '  1. Abrí https://supabase.com/dashboard/project/kpvjdzdynqfhqfiatwqz\n' +
        '  2. Avatar (arriba derecha) → Account → Access Tokens → Generate new token\n' +
        '  3. Pegá sbp_... en BACKEND/.env.supabase-keys.local → SUPABASE_ACCESS_TOKEN\n' +
        '  4. npm run configure:supabase-keys && npm run supabase:cli-check\n',
    );
  }

  throw new Error(`No se pudo verificar acceso Management API a ${projectRef}`);
}

function buildAccessDeniedError(projectRef: string, detail: string): Error {
  return new Error(
    `Sin permisos de Management API para ${projectRef}.\n` +
      `Detalle: ${detail}\n\n` +
      'Causas comunes:\n' +
      '  • Token creado con otra cuenta (la de DISCAS/Kairo, no la de EVIDENTE)\n' +
      '  • Pegaste sb_secret o anon JWT en vez de Access Token sbp_*\n\n' +
      'Arreglo:\n' +
      '  A) Token correcto: dashboard EVIDENTE → Account → Access Tokens → sbp_...\n' +
      '  B) Login CLI: npx supabase logout && npx supabase login (cuenta EVIDENTE)\n' +
      '  C) Manual: npm run supabase:functions:dashboard-guide\n',
  );
}
