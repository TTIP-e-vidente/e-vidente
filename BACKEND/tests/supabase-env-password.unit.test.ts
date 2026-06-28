import assert from 'assert/strict';
import { detectLikelyTruncatedPassword } from '../scripts/lib/supabase-env';

assert.equal(detectLikelyTruncatedPassword('POSTGRES_PASSWORD=evidente2026#?'), true);
assert.equal(detectLikelyTruncatedPassword('POSTGRES_PASSWORD="evidente2026#?"'), false);
assert.equal(detectLikelyTruncatedPassword('POSTGRES_PASSWORD=secret'), false);

console.log('supabase-env-password.unit.test OK');
