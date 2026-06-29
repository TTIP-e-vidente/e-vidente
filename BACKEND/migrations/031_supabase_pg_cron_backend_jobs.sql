-- Supabase: pg_cron + pg_net para disparar jobs del backend Express (/internal/jobs/*).
-- Secrets y URL se cargan con: npm run setup:supabase:cron
-- Requiere BACKEND_BASE_URL público (Render, etc.); localhost no es alcanzable desde Supabase.

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron no disponible en este host: %', SQLERRM;
END $$;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_net no disponible en este host: %', SQLERRM;
END $$;

CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.internal_cron_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON TABLE private.internal_cron_settings FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.invoke_backend_internal_job(job_path text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, extensions, net, cron, pg_catalog
AS $$
DECLARE
  base_url text;
  job_secret text;
  target_url text;
  headers jsonb;
BEGIN
  SELECT value INTO base_url
  FROM private.internal_cron_settings
  WHERE key = 'backend_base_url';

  SELECT value INTO job_secret
  FROM private.internal_cron_settings
  WHERE key = 'email_cron_secret';

  IF base_url IS NULL OR btrim(base_url) = '' OR job_secret IS NULL OR btrim(job_secret) = '' THEN
    RAISE LOG '[evidente-cron] omitido: faltan backend_base_url o email_cron_secret';
    RETURN NULL;
  END IF;

  IF base_url ~* '(^https?://(127\.0\.0\.1|localhost)(:|/|$))' THEN
    RAISE LOG '[evidente-cron] omitido: BACKEND_BASE_URL local no es alcanzable desde Supabase (%).', base_url;
    RETURN NULL;
  END IF;

  target_url := rtrim(base_url, '/') || '/internal/jobs/' || job_path;
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'X-Job-Secret', job_secret
  );

  RETURN net.http_post(
    url := target_url,
    headers := headers,
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_backend_internal_job(text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.refresh_evidente_cron_jobs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, cron, pg_catalog
AS $$
DECLARE
  job record;
  scheduled integer := 0;
BEGIN
  IF to_regnamespace('cron') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'pg_cron_not_installed');
  END IF;

  FOR job IN
    SELECT jobid
    FROM cron.job
    WHERE jobname IN (
      'evidente-streak-emails',
      'evidente-retry-failed-am',
      'evidente-retry-failed-pm',
      'evidente-refresh-leaderboard'
    )
  LOOP
    PERFORM cron.unschedule(job.jobid);
  END LOOP;

  PERFORM cron.schedule(
    'evidente-streak-emails',
    '0 22 * * *',
    $cron$SELECT private.invoke_backend_internal_job('streak-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-retry-failed-am',
    '0 11 * * *',
    $cron$SELECT private.invoke_backend_internal_job('retry-failed-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-retry-failed-pm',
    '0 23 * * *',
    $cron$SELECT private.invoke_backend_internal_job('retry-failed-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-refresh-leaderboard',
    '15 * * * *',
    $cron$SELECT private.invoke_backend_internal_job('refresh-leaderboard');$cron$
  );
  scheduled := scheduled + 1;

  RETURN jsonb_build_object('ok', true, 'scheduled', scheduled);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_evidente_cron_jobs() FROM PUBLIC;
