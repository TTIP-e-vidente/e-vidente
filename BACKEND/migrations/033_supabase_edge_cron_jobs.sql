-- pg_cron → Supabase Edge Functions (internal-job) en lugar de Express.
-- Configurar con: npm run setup:supabase:cron  (ahora setea supabase_functions_url + anon key)

CREATE OR REPLACE FUNCTION private.invoke_evidente_internal_job(job_path text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, extensions, net, cron, pg_catalog
AS $$
DECLARE
  functions_url text;
  anon_key text;
  job_secret text;
  backend_url text;
  target_url text;
  headers jsonb;
  req_id bigint;
  skip_reason text;
BEGIN
  SELECT value INTO functions_url
  FROM private.internal_cron_settings
  WHERE key = 'supabase_functions_url';

  SELECT value INTO anon_key
  FROM private.internal_cron_settings
  WHERE key = 'supabase_anon_key';

  SELECT value INTO job_secret
  FROM private.internal_cron_settings
  WHERE key = 'email_cron_secret';

  IF functions_url IS NOT NULL AND btrim(functions_url) <> ''
     AND anon_key IS NOT NULL AND btrim(anon_key) <> ''
     AND job_secret IS NOT NULL AND btrim(job_secret) <> '' THEN
    target_url := rtrim(functions_url, '/') || '/internal-job';
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Job-Secret', job_secret,
      'Authorization', 'Bearer ' || anon_key,
      'apikey', anon_key
    );

    req_id := net.http_post(
      url := target_url,
      headers := headers,
      body := jsonb_build_object('job', job_path),
      timeout_milliseconds := 120000
    );

    INSERT INTO private.cron_invocation_log (job_path, target_url, request_id)
    VALUES (job_path, target_url, req_id);

    RETURN req_id;
  END IF;

  -- Fallback legacy: Express /internal/jobs/*
  SELECT value INTO backend_url
  FROM private.internal_cron_settings
  WHERE key = 'backend_base_url';

  IF backend_url IS NULL OR btrim(backend_url) = '' OR job_secret IS NULL OR btrim(job_secret) = '' THEN
    skip_reason := 'missing_edge_or_backend_settings';
    INSERT INTO private.cron_invocation_log (job_path, skipped_reason)
    VALUES (job_path, skip_reason);
    RAISE LOG '[evidente-cron] omitido: faltan supabase_functions_url o backend_base_url';
    RETURN NULL;
  END IF;

  IF backend_url ~* '(^https?://(127\.0\.0\.1|localhost)(:|/|$))' THEN
    skip_reason := 'localhost_not_reachable';
    INSERT INTO private.cron_invocation_log (job_path, target_url, skipped_reason)
    VALUES (job_path, backend_url, skip_reason);
    RAISE LOG '[evidente-cron] omitido: BACKEND_BASE_URL local (%)', backend_url;
    RETURN NULL;
  END IF;

  target_url := rtrim(backend_url, '/') || '/internal/jobs/' || job_path;
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'X-Job-Secret', job_secret
  );

  req_id := net.http_post(
    url := target_url,
    headers := headers,
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );

  INSERT INTO private.cron_invocation_log (job_path, target_url, request_id)
  VALUES (job_path, target_url, req_id);

  RETURN req_id;
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_evidente_internal_job(text) FROM PUBLIC;

-- Reemplazar invocador usado por los crons
CREATE OR REPLACE FUNCTION private.invoke_backend_internal_job(job_path text)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = private, public
AS $$
  SELECT private.invoke_evidente_internal_job(job_path);
$$;

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
    $cron$SELECT private.invoke_evidente_internal_job('streak-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-retry-failed-am',
    '0 11 * * *',
    $cron$SELECT private.invoke_evidente_internal_job('retry-failed-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-retry-failed-pm',
    '0 23 * * *',
    $cron$SELECT private.invoke_evidente_internal_job('retry-failed-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-refresh-leaderboard',
    '15 * * * *',
    $cron$SELECT private.invoke_evidente_internal_job('refresh-leaderboard');$cron$
  );
  scheduled := scheduled + 1;

  RETURN jsonb_build_object('ok', true, 'scheduled', scheduled);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'reason', SQLERRM);
END;
$$;
