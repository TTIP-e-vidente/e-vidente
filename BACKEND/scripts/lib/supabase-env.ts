import fs from 'fs';

export type SupabaseHostKind = 'direct' | 'pooler' | 'local' | 'unknown';

export const PLACEHOLDER_JWT_SECRETS = new Set([
  'cambiar_por_secret_largo_staging',
  'evidente_local_dev_secret_change_me',
]);

export const PLACEHOLDER_CRON_SECRETS = new Set([
  'cambiar_staging',
  'evidente_email_cron_local_dev_change_me',
  'staging_ci_secret',
]);

export interface EnvFieldCheck {
  key: string;
  ok: boolean;
  message: string;
  hint?: string;
}

export function detectSupabaseHostKind(host: string | undefined): SupabaseHostKind {
  const value = host?.trim().toLowerCase() ?? '';
  if (!value || value === 'localhost' || value === '127.0.0.1') {
    return 'local';
  }
  if (value.includes('.pooler.supabase.com')) {
    return 'pooler';
  }
  if (value.includes('.supabase.co')) {
    return 'direct';
  }
  return 'unknown';
}

export function isPlaceholderSecret(value: string | undefined, placeholders: ReadonlySet<string>): boolean {
  const trimmed = value?.trim() ?? '';
  return trimmed.length === 0 || placeholders.has(trimmed);
}

/** dotenv trata `#` como inicio de comentario si el valor no está entre comillas. */
export function detectLikelyTruncatedPassword(rawLine: string | undefined): boolean {
  if (!rawLine) {
    return false;
  }
  const match = rawLine.match(/^POSTGRES_PASSWORD=(.*)$/);
  if (!match) {
    return false;
  }
  const value = match[1].trim();
  if (value.startsWith('"') || value.startsWith("'")) {
    return false;
  }
  return value.includes('#') || value.includes(' ');
}

export function envFileExists(envPath: string): boolean {
  return fs.existsSync(envPath);
}

export function validateSupabaseEnvFields(options: {
  envPath: string;
  requirePublicUrl?: boolean;
  requireBrevo?: boolean;
  requireEdgeFunctions?: boolean;
}): EnvFieldCheck[] {
  const checks: EnvFieldCheck[] = [];
  const host = process.env.POSTGRES_HOST?.trim() ?? '';
  const hostKind = detectSupabaseHostKind(host);

  checks.push({
    key: 'POSTGRES_SSL',
    ok: process.env.POSTGRES_SSL === 'true',
    message: process.env.POSTGRES_SSL === 'true' ? 'SSL activo' : 'POSTGRES_SSL debe ser true',
    hint: 'POSTGRES_SSL=true',
  });

  checks.push({
    key: 'POSTGRES_HOST',
    ok: host.length > 0 && !host.includes('TU_PROJECT_REF'),
    message: host.length > 0 ? `Host: ${host} (${hostKind})` : 'Falta POSTGRES_HOST',
    hint: 'db.<ref>.supabase.co para migrate; pooler para runtime',
  });

  checks.push({
    key: 'POSTGRES_PASSWORD',
    ok: Boolean(process.env.POSTGRES_PASSWORD?.trim()),
    message: process.env.POSTGRES_PASSWORD?.trim() ? 'Password configurada' : 'Falta POSTGRES_PASSWORD',
    hint: 'Si tiene # o espacios, usá POSTGRES_PASSWORD="..." en el .env',
  });

  if (options.envPath && envFileExists(options.envPath)) {
    const raw = fs.readFileSync(options.envPath, 'utf8');
    const passwordLine = raw.split('\n').find((line) => line.startsWith('POSTGRES_PASSWORD='));
    if (detectLikelyTruncatedPassword(passwordLine)) {
      checks.push({
        key: 'POSTGRES_PASSWORD_QUOTING',
        ok: false,
        message: 'POSTGRES_PASSWORD parece truncada (# interpretado como comentario)',
        hint: 'POSTGRES_PASSWORD="tu-password-completo"',
      });
    }
  }

  checks.push({
    key: 'POSTGRES_USER',
    ok: Boolean(process.env.POSTGRES_USER?.trim()),
    message: process.env.POSTGRES_USER?.trim()
      ? `User: ${process.env.POSTGRES_USER}`
      : 'Falta POSTGRES_USER',
  });

  const jwtSecret = process.env.JWT_SECRET?.trim() ?? '';
  checks.push({
    key: 'JWT_SECRET',
    ok: jwtSecret.length >= 16 && !isPlaceholderSecret(jwtSecret, PLACEHOLDER_JWT_SECRETS),
    message: isPlaceholderSecret(jwtSecret, PLACEHOLDER_JWT_SECRETS)
      ? 'JWT_SECRET es placeholder o muy corto'
      : 'JWT_SECRET configurado',
    hint: 'Generá un secret largo (32+ chars)',
  });

  const cronSecret = process.env.EMAIL_CRON_SECRET?.trim() ?? '';
  checks.push({
    key: 'EMAIL_CRON_SECRET',
    ok: cronSecret.length >= 12 && !isPlaceholderSecret(cronSecret, PLACEHOLDER_CRON_SECRETS),
    message: isPlaceholderSecret(cronSecret, PLACEHOLDER_CRON_SECRETS)
      ? 'EMAIL_CRON_SECRET es placeholder o muy corto'
      : 'EMAIL_CRON_SECRET configurado',
    hint: 'Debe coincidir con el secret de GitHub Actions (email-cron.yml)',
  });

  if (options.requirePublicUrl) {
    const publicUrl = process.env.BACKEND_BASE_URL?.trim() ?? '';
    checks.push({
      key: 'BACKEND_BASE_URL',
      ok: publicUrl.startsWith('https://'),
      message: publicUrl ? `URL pública: ${publicUrl}` : 'Falta BACKEND_BASE_URL (https://...)',
      hint: 'Requerido para crons de GitHub Actions y webhooks Brevo',
    });
  }

  if (options.requireBrevo || process.env.EMAIL_ENABLED === 'true') {
    const brevoKey = process.env.BREVO_API_KEY?.trim() ?? '';
    const sender = process.env.BREVO_SENDER_EMAIL?.trim() ?? '';
    checks.push({
      key: 'BREVO_API_KEY',
      ok: brevoKey.length > 0,
      message: brevoKey ? 'Brevo API key presente' : 'Falta BREVO_API_KEY',
    });
    checks.push({
      key: 'BREVO_SENDER_EMAIL',
      ok: sender.length > 0 && sender.includes('@'),
      message: sender ? `Sender: ${sender}` : 'Falta BREVO_SENDER_EMAIL',
    });
  }

  const projectRef = process.env.SUPABASE_PROJECT_REF?.trim() ?? '';
  if (projectRef && !projectRef.includes('TU_')) {
    checks.push({
      key: 'SUPABASE_PROJECT_REF',
      ok: true,
      message: `Project ref: ${projectRef}`,
    });
  } else if (host.includes('TU_PROJECT_REF')) {
    checks.push({
      key: 'SUPABASE_PROJECT_REF',
      ok: false,
      message: 'Falta SUPABASE_PROJECT_REF o reemplazá TU_PROJECT_REF en POSTGRES_HOST',
      hint: 'SUPABASE_PROJECT_REF=<tu-ref>',
    });
  }

  if (options.requireEdgeFunctions) {
    const anonKey = process.env.SUPABASE_ANON_KEY?.trim() ?? '';
    checks.push({
      key: 'SUPABASE_ANON_KEY',
      ok: anonKey.length > 20,
      message: anonKey ? 'Anon key presente (Godot + pg_cron → Edge)' : 'Falta SUPABASE_ANON_KEY',
      hint: 'Dashboard Supabase → Settings → API → anon public',
    });
  }

  if (hostKind === 'pooler') {
    const poolerUserOk = /^postgres\.[a-z0-9]+$/.test(process.env.POSTGRES_USER?.trim() ?? '');
    checks.push({
      key: 'POSTGRES_USER_POOLER',
      ok: poolerUserOk,
      message: poolerUserOk
        ? `User pooler: ${process.env.POSTGRES_USER}`
        : 'Con pooler, POSTGRES_USER debe ser postgres.<project-ref>',
    });
    checks.push({
      key: 'POSTGRES_HOST_KIND',
      ok: true,
      message: 'Usando Session pooler (recomendado para runtime)',
    });
  } else if (hostKind === 'direct') {
    checks.push({
      key: 'POSTGRES_HOST_KIND',
      ok: true,
      message: 'Host directo (ideal para migrate; para runtime considerá el pooler)',
      hint: 'Después de migrate, cambiá a aws-0-….pooler.supabase.com',
    });
  }

  if (!envFileExists(options.envPath)) {
    checks.unshift({
      key: 'ENV_FILE',
      ok: false,
      message: `No existe ${options.envPath}`,
      hint: 'npm run supabase:init',
    });
  }

  return checks;
}

export function printEnvChecks(checks: EnvFieldCheck[]): void {
  for (const check of checks) {
    console.log(`  ${check.ok ? 'OK' : 'FAIL'} — ${check.message}`);
    if (!check.ok && check.hint) {
      console.log(`         → ${check.hint}`);
    }
  }
}

export function hasFailedChecks(checks: EnvFieldCheck[]): boolean {
  return checks.some((check) => !check.ok);
}
