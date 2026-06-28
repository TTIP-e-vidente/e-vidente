import assert from 'assert/strict';
import { detectSupabaseHostKind } from '../scripts/lib/supabase-env';

assert.equal(detectSupabaseHostKind('db.abc.supabase.co'), 'direct');
assert.equal(detectSupabaseHostKind('aws-0-us-east-1.pooler.supabase.com'), 'pooler');
assert.equal(detectSupabaseHostKind('localhost'), 'local');

console.log('supabase-env.unit.test OK');
