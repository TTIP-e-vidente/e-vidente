const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', 'src', 'modules', 'email', 'assets');
const dest = path.join(__dirname, '..', 'dist', 'modules', 'email', 'assets');

if (!fs.existsSync(src)) {
  console.warn('[build] email assets source missing:', src);
  process.exit(0);
}

fs.cpSync(src, dest, { recursive: true });
console.log('[build] copied email assets to dist/modules/email/assets');
