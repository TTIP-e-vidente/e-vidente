import { assertSupabaseOnlyDev } from './lib/supabase-only-policy';

const entrypoint = process.argv[2] ?? 'dev:local';
assertSupabaseOnlyDev(entrypoint);
