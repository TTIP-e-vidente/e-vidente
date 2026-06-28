import assert from 'assert/strict';
import {
  buildPoolerHost,
  buildSupabaseConnectionTargets,
  extractSupabaseProjectRef,
} from '../scripts/lib/supabase-connect';

process.env.SUPABASE_PROJECT_REF = 'kpvjdzdynqfhqfiatwqz';
process.env.POSTGRES_HOST = 'db.kpvjdzdynqfhqfiatwqz.supabase.co';
process.env.POSTGRES_USER = 'postgres';
process.env.POSTGRES_DB = 'postgres';
process.env.POSTGRES_SSL = 'true';

assert.equal(extractSupabaseProjectRef(), 'kpvjdzdynqfhqfiatwqz');

process.env.POSTGRES_USER = 'postgres.kpvjdzdynqfhqfiatwqz';
assert.equal(extractSupabaseProjectRef(), 'kpvjdzdynqfhqfiatwqz');

const targets = buildSupabaseConnectionTargets();
assert.ok(targets.length >= 3);
assert.equal(targets[0].host, 'db.kpvjdzdynqfhqfiatwqz.supabase.co');
assert.ok(targets.some((target) => target.host === buildPoolerHost('sa-east-1')));

console.log('supabase-connect.unit.test OK');
