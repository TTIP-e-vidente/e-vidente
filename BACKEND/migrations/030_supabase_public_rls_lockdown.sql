-- Supabase expone el schema public vía Data API. Sin policies, RLS bloquea anon/authenticated.
-- El backend Node conecta como postgres (bypass RLS) y no se ve afectado.

DO $$
DECLARE
  table_name text;
BEGIN
  FOR table_name IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> 'schema_migrations'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
  END LOOP;
END $$;
