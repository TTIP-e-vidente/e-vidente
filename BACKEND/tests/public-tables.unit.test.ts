import assert from 'assert/strict';
import { sortTablesByForeignKeys } from '../scripts/lib/public-tables';

function testTopologicalOrder(): void {
  const tables = ['games', 'users', 'profiles', 'streaks'];
  const edges = [
    { childTable: 'profiles', parentTable: 'users' },
    { childTable: 'profiles', parentTable: 'streaks' },
    { childTable: 'games', parentTable: 'users' },
    { childTable: 'streaks', parentTable: 'users' },
  ];

  const ordered = sortTablesByForeignKeys(tables, edges);
  const indexOf = (table: string) => ordered.indexOf(table);

  assert.ok(indexOf('users') < indexOf('profiles'));
  assert.ok(indexOf('users') < indexOf('streaks'));
  assert.ok(indexOf('users') < indexOf('games'));
  assert.ok(indexOf('streaks') < indexOf('profiles'));
}

testTopologicalOrder();
console.log('public-tables.unit.test OK');
