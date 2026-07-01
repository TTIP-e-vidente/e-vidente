import assert from 'assert/strict';
import { buildStorageNamespace } from '../scripts/lib/godot-backend-config';

assert.equal(
  buildStorageNamespace({
    db: 'supabase',
    apiMode: 'supabase_edge',
    envFile: '.env.staging',
    baseUrl: 'https://example.supabase.co/functions/v1',
  }),
  'supabase-env-staging'
);

assert.equal(
  buildStorageNamespace({
    db: 'local',
    apiMode: 'local',
    envFile: '.env.local',
    baseUrl: 'http://localhost:3010',
  }),
  'local-env-local'
);

assert.equal(
  buildStorageNamespace({
    db: 'local',
    apiMode: 'local',
    envFile: '../odd file!.env',
    baseUrl: 'http://localhost:3010',
  }),
  'local-odd-file-env'
);

console.log('godot-backend-config.unit.test OK');
