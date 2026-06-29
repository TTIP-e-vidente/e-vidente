import fs from 'fs';
import path from 'path';

const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(ROOT, 'supabase/functions/_shared/repositories');

function denoPort(content: string, importFixes: Array<[RegExp, string]> = []): string {
  let c = content;
  c = c.replace(
    /import \{ PoolClient \} from ['"]pg['"];?/g,
    "import type { Client } from 'https://deno.land/x/postgres@v0.19.3/mod.ts';",
  );
  c = c.replace(/PoolClient/g, 'Client');
  c = c.replace(/await client\.query</g, 'await client.queryObject<');
  c = c.replace(/await client\.query\(/g, 'await client.queryObject(');
  for (const [from, to] of importFixes) {
    c = c.replace(from, to);
  }
  return c;
}

fs.mkdirSync(OUT, { recursive: true });

const pairs: Array<[string, string, Array<[RegExp, string]>]> = [
  [
    'BACKEND/src/modules/profile/profile.repository.ts',
    'profile.ts',
    [[/from '\.\/profile\.types'/, "from '../types/player.ts'"]],
  ],
  [
    'BACKEND/src/modules/history-game/history-game.repository.ts',
    'history-game.ts',
    [[/from '\.\/history-game\.types'/, "from '../types/player.ts'"]],
  ],
  [
    'BACKEND/src/modules/game/game.repository.ts',
    'game.ts',
    [
      [/from '\.\/game\.types'/, "from '../types/player.ts'"],
      [/from '\.\.\/history-game\/history-game\.repository'/, "from './history-game.ts'"],
    ],
  ],
  [
    'BACKEND/src/modules/progreso-restriccion/progreso-restriccion.repository.ts',
    'progress.ts',
    [
      [/from '\.\/progreso-restriccion\.types'/, "from '../types/player.ts'"],
      [/from '\.\.\/history-game\/history-game\.repository'/, "from './history-game.ts'"],
    ],
  ],
  [
    'BACKEND/src/modules/streak/streak.repository.ts',
    'streak.ts',
    [
      [/from '\.\/streak\.types'/, "from '../types/player.ts'"],
      [/from '\.\.\/profile\/profile\.repository'/, "from './profile.ts'"],
    ],
  ],
  [
    'BACKEND/src/modules/image/image.repository.ts',
    'image.ts',
    [],
  ],
];

for (const [srcRel, outName, fixes] of pairs) {
  const src = path.join(ROOT, srcRel);
  const content = denoPort(fs.readFileSync(src, 'utf8'), fixes);
  fs.writeFileSync(path.join(OUT, outName), content);
  console.log('ported', outName);
}
