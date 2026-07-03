-- Rachas: tercer aviso a las 23:00 ART (1h antes de perderla), sumado a los
-- ya existentes de las 18:00 (en riesgo) y las 00:00 (perdida).
--   18:00 ART → streak-at-risk-emails      (21:00 UTC)
--   23:00 ART → streak-last-chance-emails  (02:00 UTC del día siguiente)
--   00:00 ART → streak-lost-emails         (03:00 UTC)
-- Reprogramar: npm run setup:supabase:cron

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
      'evidente-streak-at-risk',
      'evidente-streak-last-chance',
      'evidente-streak-lost',
      'evidente-retry-failed-am',
      'evidente-retry-failed-pm',
      'evidente-refresh-leaderboard'
    )
  LOOP
    PERFORM cron.unschedule(job.jobid);
  END LOOP;

  PERFORM cron.schedule(
    'evidente-streak-at-risk',
    '0 21 * * *',
    $cron$SELECT private.invoke_evidente_internal_job('streak-at-risk-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-streak-last-chance',
    '0 2 * * *',
    $cron$SELECT private.invoke_evidente_internal_job('streak-last-chance-emails');$cron$
  );
  scheduled := scheduled + 1;

  PERFORM cron.schedule(
    'evidente-streak-lost',
    '0 3 * * *',
    $cron$SELECT private.invoke_evidente_internal_job('streak-lost-emails');$cron$
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

SELECT private.refresh_evidente_cron_jobs();
