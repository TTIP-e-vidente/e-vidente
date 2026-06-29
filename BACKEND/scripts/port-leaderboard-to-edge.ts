import fs from 'fs';
import path from 'path';

const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(ROOT, 'supabase/functions/_shared/leaderboard');

function portLeaderboardRepo(content: string): string {
  let c = content;
  c = c.replace(
    /import \{ pool, query \} from '..\/..\/config\/database';/,
    "import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';\nimport { queryRows, withDb } from '../db.ts';",
  );
  c = c.replace(/from '\.\/leaderboard\.types'/g, "from './types.ts'");
  c = c.replace(/from '..\/..\/config\/restrictions'/g, "from '../restrictions.ts'");
  c = c.replace(/await query</g, 'await queryRows<');
  c = c.replace(/const result = await queryRows/g, 'const rows = await queryRows');
  c = c.replace(/result\.rows/g, 'rows');
  c = c.replace(/const snapshotResult = await queryRows/g, 'const snapshotRows = await queryRows');
  c = c.replace(/snapshotResult\.rows/g, 'snapshotRows');
  c = c.replace(/await client\.query</g, 'await client.queryObject<');
  c = c.replace(/await client\.query\(/g, 'await client.queryObject(');
  c = c.replace(/insertResult\.rowCount/g, 'insertResult.rowCount ?? 0');
  c = c.replace(
    /const client = await pool\.connect\(\);\s*try \{\s*await client\.queryObject\('BEGIN'\);/g,
    'return await withDb(async (client) => {',
  );
  // Manual fix for doRefresh - rewrite function
  return c;
}

fs.mkdirSync(OUT, { recursive: true });

const types = fs.readFileSync(
  path.join(ROOT, 'BACKEND/src/modules/leaderboard/leaderboard.types.ts'),
  'utf8',
).replace(/from '..\/..\/config\/restrictions'/g, "from '../restrictions.ts'");
fs.writeFileSync(path.join(OUT, 'types.ts'), types);

const mapper = fs.readFileSync(
  path.join(ROOT, 'BACKEND/src/modules/leaderboard/leaderboard.mapper.ts'),
  'utf8',
).replace(/from '\.\/leaderboard\.types'/g, "from './types.ts'");
fs.writeFileSync(path.join(OUT, 'mapper.ts'), mapper);

let repo = fs.readFileSync(
  path.join(ROOT, 'BACKEND/src/modules/leaderboard/leaderboard.repository.ts'),
  'utf8',
);

repo = repo.replace(
  /import \{ pool, query \} from '..\/..\/config\/database';/,
  "import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';\nimport { queryRows, withDb } from '../db.ts';",
);
repo = repo.replace(/from '\.\/leaderboard\.types'/g, "from './types.ts'");
repo = repo.replace(/from '..\/..\/config\/restrictions'/g, "from '../restrictions.ts'");

repo = repo.replace(
  /async function doRefresh\([\s\S]*?finally \{\s*client\.release\(\);\s*\}\s*\}/,
  `async function doRefresh(
  scope: LeaderboardScope,
  insertSql: string,
  insertParams: unknown[],
  startedAt: Date,
): Promise<number> {
  return await withDb(async (client) => {
    await client.queryObject('BEGIN');
    try {
      const genResult = await client.queryObject<{ current_generation: number }>(
        \`SELECT current_generation FROM leaderboard_meta WHERE scope = $1 FOR UPDATE\`,
        [scope],
      );
      const nextGen = (genResult.rows[0]?.current_generation ?? 0) + 1;
      const insertResult = await client.queryObject(insertSql, [...insertParams, nextGen]);
      const rowsInserted = insertResult.rowCount ?? 0;
      const durationMs = Date.now() - startedAt.getTime();
      await client.queryObject(
        \`
          UPDATE leaderboard_meta
          SET
            last_refreshed_at  = now(),
            row_count          = $2,
            duration_ms        = $3,
            current_generation = $1,
            error_message      = NULL
          WHERE scope = $4
        \`,
        [nextGen, rowsInserted, durationMs, scope],
      );
      await client.queryObject(
        \`DELETE FROM leaderboard_snapshots WHERE scope = $1 AND generation < $2\`,
        [scope, nextGen],
      );
      await client.queryObject('COMMIT');
      return rowsInserted;
    } catch (error) {
      await client.queryObject('ROLLBACK');
      const message = error instanceof Error ? error.message.slice(0, 500) : String(error);
      await queryRows(
        \`UPDATE leaderboard_meta SET error_message = $1 WHERE scope = $2\`,
        [message, scope],
      ).catch(() => {});
      throw error;
    }
  });
}`,
);

repo = repo.replace(/await query<([^>]+)>\(/g, 'await queryRows<$1>(');
repo = repo.replace(/const result = await queryRows/g, 'const rows = await queryRows');
repo = repo.replace(/return result\.rows\.map/g, 'return rows.map');
repo = repo.replace(/const row = result\.rows\[0\]/g, 'const row = rows[0]');
repo = repo.replace(/if \(result\.rows\.length/g, 'if (rows.length');
repo = repo.replace(/result\.rows\.length/g, 'rows.length');
repo = repo.replace(/result\.rows\.map/g, 'rows.map');
repo = repo.replace(/const snapshotResult = await queryRows/g, 'const snapshotRows = await queryRows');
repo = repo.replace(/snapshotResult\.rows/g, 'snapshotRows');

fs.writeFileSync(path.join(OUT, 'repository.ts'), repo);
console.log('ported leaderboard module');
