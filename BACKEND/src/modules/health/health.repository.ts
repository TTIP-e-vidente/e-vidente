import { query } from '../../config/database';

export interface DbInfoRow {
  current_database: string;
  current_user: string;
}

export async function getDbInfo(): Promise<DbInfoRow> {
  const result = await query<DbInfoRow>('SELECT current_database(), current_user;');
  return result.rows[0];
}

export async function getAppliedMigrationCount(): Promise<number> {
  const result = await query<{ count: string }>(
    'SELECT COUNT(*)::text AS count FROM schema_migrations;'
  );
  return Number.parseInt(result.rows[0]?.count ?? '0', 10);
}

export type SupabaseCronJobRow = {
  jobname: string;
  schedule: string;
  active: boolean;
};

export type SupabaseCronInvocationRow = {
  job_path: string;
  target_url: string | null;
  skipped_reason: string | null;
  request_id: string | null;
  created_at: Date;
};

export async function getSupabaseCronSnapshot(): Promise<{
  available: boolean;
  supabase_functions_url?: string | null;
  jobs: SupabaseCronJobRow[];
  recent_invocations: SupabaseCronInvocationRow[];
  last_pg_cron_run?: { jobname: string; status: string; start_time: Date } | null;
}> {
  try {
    const settings = await query<{ key: string; value: string }>(
      `SELECT key, value FROM private.internal_cron_settings
       WHERE key IN ('supabase_functions_url', 'supabase_anon_key', 'email_cron_secret');`
    );
    const settingsMap = new Map(settings.rows.map((row) => [row.key, row.value]));
    const functionsUrl = settingsMap.get('supabase_functions_url') ?? null;

    const jobs = await query<SupabaseCronJobRow>(
      `
        SELECT jobname, schedule, active
        FROM cron.job
        WHERE jobname LIKE 'evidente-%'
        ORDER BY jobname;
      `
    );

    const invocations = await query<{
      job_path: string;
      target_url: string | null;
      skipped_reason: string | null;
      request_id: string | null;
      created_at: Date;
    }>(
      `
        SELECT job_path, target_url, skipped_reason, request_id::text, created_at
        FROM private.cron_invocation_log
        ORDER BY created_at DESC
        LIMIT 8;
      `
    );

    let lastPgCronRun: { jobname: string; status: string; start_time: Date } | null = null;
    try {
      const runDetails = await query<{ jobname: string; status: string; start_time: Date }>(
        `
          SELECT j.jobname, d.status, d.start_time
          FROM cron.job_run_details d
          INNER JOIN cron.job j ON j.jobid = d.jobid
          WHERE j.jobname LIKE 'evidente-%'
          ORDER BY d.start_time DESC
          LIMIT 1;
        `
      );
      lastPgCronRun = runDetails.rows[0] ?? null;
    } catch {
      lastPgCronRun = null;
    }

    return {
      available: true,
      supabase_functions_url: functionsUrl,
      jobs: jobs.rows,
      recent_invocations: invocations.rows,
      last_pg_cron_run: lastPgCronRun
    };
  } catch {
    return { available: false, jobs: [], recent_invocations: [] };
  }
}
