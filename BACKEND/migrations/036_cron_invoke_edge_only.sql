-- pg_cron → Supabase Edge únicamente (sin fallback Express).
-- Reprogramar: npm run setup:supabase:cron

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

  IF functions_url IS NULL OR btrim(functions_url) = ''
     OR anon_key IS NULL OR btrim(anon_key) = ''
     OR job_secret IS NULL OR btrim(job_secret) = '' THEN
    skip_reason := 'missing_edge_cron_settings';
    INSERT INTO private.cron_invocation_log (job_path, skipped_reason)
    VALUES (job_path, skip_reason);
    RAISE LOG '[evidente-cron] omitido: faltan supabase_functions_url, supabase_anon_key o email_cron_secret';
    RETURN NULL;
  END IF;

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
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_evidente_internal_job(text) FROM PUBLIC;
