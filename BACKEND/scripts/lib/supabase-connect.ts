import dns from 'dns/promises';
import fs from 'fs';
import { Pool, PoolConfig } from 'pg';
import { createPostgresPoolConfig } from '../../src/config/postgresPoolConfig';
import { detectSupabaseHostKind, type SupabaseHostKind } from './supabase-env';

/** Regiones comunes del Session pooler (puerto 5432). */
export const DEFAULT_POOLER_REGIONS = [
  'us-east-1',
  'sa-east-1',
  'us-west-1',
  'eu-west-1',
  'ap-southeast-1',
  'eu-central-1',
  'ap-northeast-1',
] as const;

export const POOLER_PREFIXES = ['aws-1', 'aws-0'] as const;

export interface SupabaseConnectionTarget {
  label: string;
  host: string;
  port: number;
  user: string;
  database: string;
  kind: SupabaseHostKind;
}

export interface SupabaseConnectionResult {
  target: SupabaseConnectionTarget;
  database: string;
  user: string;
}

export function extractSupabaseProjectRef(): string | null {
  const fromEnv = process.env.SUPABASE_PROJECT_REF?.trim();
  if (fromEnv && !fromEnv.includes('TU_')) {
    return fromEnv;
  }

  const host = process.env.POSTGRES_HOST?.trim().toLowerCase() ?? '';
  const directMatch = host.match(/^db\.([a-z0-9]+)\.supabase\.co$/);
  if (directMatch) {
    return directMatch[1];
  }

  const user = process.env.POSTGRES_USER?.trim() ?? '';
  const poolerUserMatch = user.match(/^postgres\.([a-z0-9]+)$/);
  if (poolerUserMatch) {
    return poolerUserMatch[1];
  }

  return null;
}

export function buildPoolerHost(region: string, prefix = 'aws-0'): string {
  return `${prefix}-${region}.pooler.supabase.com`;
}

export function buildSupabaseConnectionTargets(): SupabaseConnectionTarget[] {
  const database = process.env.POSTGRES_DB?.trim() || 'postgres';
  const projectRef = extractSupabaseProjectRef();
  const configuredHost = process.env.POSTGRES_HOST?.trim() ?? '';
  const configuredUser = process.env.POSTGRES_USER?.trim() || 'postgres';
  const configuredPort = Number.parseInt(process.env.POSTGRES_PORT ?? '5432', 10);
  const port = Number.isNaN(configuredPort) ? 5432 : configuredPort;

  const targets: SupabaseConnectionTarget[] = [];
  const seen = new Set<string>();

  function push(target: SupabaseConnectionTarget): void {
    const key = `${target.host}|${target.port}|${target.user}`;
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    targets.push(target);
  }

  if (configuredHost) {
    push({
      label: 'configurado en POSTGRES_HOST',
      host: configuredHost,
      port,
      user: configuredUser,
      database,
      kind: detectSupabaseHostKind(configuredHost),
    });
  }

  if (projectRef) {
    push({
      label: 'directo Supabase',
      host: `db.${projectRef}.supabase.co`,
      port: 5432,
      user: 'postgres',
      database,
      kind: 'direct',
    });

    const regions = resolvePoolerRegions();
    for (const prefix of POOLER_PREFIXES) {
      for (const region of regions) {
        push({
          label: `pooler ${prefix} ${region}`,
          host: buildPoolerHost(region, prefix),
          port: 5432,
          user: `postgres.${projectRef}`,
          database,
          kind: 'pooler',
        });
      }
    }
  }

  return targets;
}

function resolvePoolerRegions(): string[] {
  const configured = process.env.SUPABASE_POOLER_REGION?.trim();
  if (configured) {
    return [configured];
  }
  return [...DEFAULT_POOLER_REGIONS];
}

export function createPoolForTarget(
  target: SupabaseConnectionTarget,
  overrides: Partial<PoolConfig> = {}
): Pool {
  return new Pool(
    createPostgresPoolConfig({
      host: target.host,
      port: target.port,
      user: target.user,
      database: target.database,
      connectionTimeoutMillis: 12_000,
      ...overrides,
    })
  );
}

export async function tryConnectTarget(
  target: SupabaseConnectionTarget
): Promise<{ ok: true; result: SupabaseConnectionResult } | { ok: false; error: string }> {
  const pool = createPoolForTarget(target);
  try {
    const result = await pool.query<{ current_database: string; current_user: string }>(
      'SELECT current_database(), current_user;'
    );
    return {
      ok: true,
      result: {
        target,
        database: result.rows[0].current_database,
        user: result.rows[0].current_user,
      },
    };
  } catch (error) {
    return { ok: false, error: (error as Error).message };
  } finally {
    await pool.end();
  }
}

export function applyConnectionTargetToProcess(target: SupabaseConnectionTarget): void {
  process.env.POSTGRES_HOST = target.host;
  process.env.POSTGRES_PORT = String(target.port);
  process.env.POSTGRES_USER = target.user;
  process.env.POSTGRES_DB = target.database;
  process.env.POSTGRES_SSL = 'true';
}

export function formatEnvPatch(target: SupabaseConnectionTarget): string {
  return [
    `POSTGRES_HOST=${target.host}`,
    `POSTGRES_PORT=${target.port}`,
    `POSTGRES_USER=${target.user}`,
    `POSTGRES_DB=${target.database}`,
    'POSTGRES_SSL=true',
  ].join('\n');
}

export function persistConnectionTargetToEnvFile(envPath: string, target: SupabaseConnectionTarget): void {
  if (!fs.existsSync(envPath)) {
    throw new Error(`No existe ${envPath}`);
  }

  let content = fs.readFileSync(envPath, 'utf8');
  const replacements: Record<string, string> = {
    POSTGRES_HOST: target.host,
    POSTGRES_PORT: String(target.port),
    POSTGRES_USER: target.user,
    POSTGRES_DB: target.database,
    POSTGRES_SSL: 'true',
  };

  for (const [key, value] of Object.entries(replacements)) {
    const pattern = new RegExp(`^${key}=.*$`, 'm');
    if (pattern.test(content)) {
      content = content.replace(pattern, `${key}=${value}`);
    } else {
      content += `\n${key}=${value}`;
    }
  }

  const projectRef = extractSupabaseProjectRef();
  if (projectRef && !/^SUPABASE_PROJECT_REF=/m.test(content)) {
    content += `\nSUPABASE_PROJECT_REF=${projectRef}`;
  }

  fs.writeFileSync(envPath, content.endsWith('\n') ? content : `${content}\n`, 'utf8');
}

export async function diagnoseHostDns(host: string): Promise<string> {
  try {
    const records = await dns.lookup(host, { all: true });
    if (records.length === 0) {
      return 'sin registros DNS';
    }
    return records.map((record) => `${record.address} (${record.family === 6 ? 'IPv6' : 'IPv4'})`).join(', ');
  } catch (error) {
    return `DNS error: ${(error as NodeJS.ErrnoException).code ?? (error as Error).message}`;
  }
}

export function isLikelyIpv6OnlyDnsIssue(host: string, errorMessage: string): boolean {
  return (
    detectSupabaseHostKind(host) === 'direct' &&
    (errorMessage.includes('ENOTFOUND') ||
      errorMessage.includes('EAI_AGAIN') ||
      errorMessage.includes('getaddrinfo'))
  );
}

export interface EnsureSupabaseConnectionOptions {
  envPath?: string;
  persistToEnvFile?: boolean;
  silent?: boolean;
}

export async function ensureSupabaseConnection(
  options: EnsureSupabaseConnectionOptions = {}
): Promise<SupabaseConnectionResult> {
  const targets = buildSupabaseConnectionTargets();
  if (targets.length === 0) {
    throw new Error('No hay targets de conexión. Configurá POSTGRES_HOST o SUPABASE_PROJECT_REF.');
  }

  const failures: string[] = [];
  const initialHost = process.env.POSTGRES_HOST?.trim() ?? '';
  const initialKind = detectSupabaseHostKind(initialHost);

  for (const target of targets) {
    if (!options.silent) {
      console.log(`  probando ${target.label}: ${target.user}@${target.host}:${target.port}`);
    }

    const attempt = await tryConnectTarget(target);
    if (attempt.ok) {
      const connected = attempt.result;
      applyConnectionTargetToProcess(target);
      if (options.persistToEnvFile && options.envPath) {
        persistConnectionTargetToEnvFile(options.envPath, target);
        if (!options.silent) {
          console.log(`  guardado en ${options.envPath}`);
        }
      } else if (
        !options.silent &&
        !options.persistToEnvFile &&
        target.kind === 'pooler' &&
        initialKind === 'direct'
      ) {
        console.log('\n  tip: el pooler funcionó. Podés persistir en .env.staging:');
        console.log(formatEnvPatch(target)
          .split('\n')
          .map((line) => `    ${line}`)
          .join('\n'));
      }

      if (!options.silent) {
        console.log(`  OK — ${connected.user}@${connected.database} via ${target.label}`);
      }
      return connected;
    }

    failures.push(`${target.label} (${target.host}): ${attempt.error}`);
  }

  const primaryHost = targets[0]?.host ?? '?';
  const dnsInfo = await diagnoseHostDns(primaryHost);
  const lines = [
    'No se pudo conectar a Supabase con ningún host probado.',
    `DNS ${primaryHost}: ${dnsInfo}`,
    '',
    'Detalle por host:',
    ...failures.map((entry) => `  - ${entry}`),
    '',
    'Soluciones:',
    '  1. Verificá POSTGRES_PASSWORD en Supabase → Settings → Database',
    '  2. Agregá SUPABASE_PROJECT_REF=<ref> y SUPABASE_POOLER_REGION=<region> en .env.staging',
    '  3. Copiá host/user del Session pooler (puerto 5432) desde el dashboard',
    '  4. Si la password tiene #, ponela entre comillas: POSTGRES_PASSWORD="..."',
    '  5. Si db.<ref>.supabase.co solo resuelve IPv6, usá el pooler (IPv4)',
  ];

  throw new Error(lines.join('\n'));
}
