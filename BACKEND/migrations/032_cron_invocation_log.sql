-- Log de invocaciones pg_cron → backend (observabilidad en Supabase SQL Editor).

CREATE TABLE IF NOT EXISTS private.cron_invocation_log (
  id bigserial PRIMARY KEY,
  job_path text NOT NULL,
  target_url text,
  request_id bigint,
  skipped_reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cron_invocation_log_created_at_idx
  ON private.cron_invocation_log (created_at DESC);

REVOKE ALL ON TABLE private.cron_invocation_log FROM PUBLIC;

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
  req_id bigint;
  skip_reason text;
BEGIN
  SELECT value INTO base_url
  FROM private.internal_cron_settings
  WHERE key = 'backend_base_url';

  SELECT value INTO job_secret
  FROM private.internal_cron_settings
  WHERE key = 'email_cron_secret';

  IF base_url IS NULL OR btrim(base_url) = '' OR job_secret IS NULL OR btrim(job_secret) = '' THEN
    skip_reason := 'missing_settings';
    INSERT INTO private.cron_invocation_log (job_path, skipped_reason)
    VALUES (job_path, skip_reason);
    RAISE LOG '[evidente-cron] omitido: faltan backend_base_url o email_cron_secret';
    RETURN NULL;
  END IF;

  IF base_url ~* '(^https?://(127\.0\.0\.1|localhost)(:|/|$))' THEN
    skip_reason := 'localhost_not_reachable';
    INSERT INTO private.cron_invocation_log (job_path, target_url, skipped_reason)
    VALUES (job_path, base_url, skip_reason);
    RAISE LOG '[evidente-cron] omitido: BACKEND_BASE_URL local (%)', base_url;
    RETURN NULL;
  END IF;

  target_url := rtrim(base_url, '/') || '/internal/jobs/' || job_path;
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

-- Retención: borrar logs > 30 días (corre 1 vez al día 04:30 UTC)
DO $$
BEGIN
  IF to_regnamespace('cron') IS NOT NULL THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname = 'evidente-prune-cron-log';

    PERFORM cron.schedule(
      'evidente-prune-cron-log',
      '30 4 * * *',
      $cron$
        DELETE FROM private.cron_invocation_log
        WHERE created_at < now() - interval '30 days';
      $cron$
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'evidente-prune-cron-log no programado: %', SQLERRM;
END $$;
