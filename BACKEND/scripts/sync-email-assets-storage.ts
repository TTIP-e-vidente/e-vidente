/**
 * Sube logo.png + íconos de email a un bucket público de Supabase Storage.
 *
 * Por qué: Brevo (y la mayoría de los clientes de mail) no renderiza
 * `data:image/...;base64,...` embebido en el HTML — el fallback local de
 * email-assets.ts existe solo para previews, no funciona para envíos reales.
 * Las Edge Functions necesitan EMAIL_LOGO_URL / EMAIL_ASSETS_BASE_URL
 * apuntando a una URL pública real; este script mantiene esa URL con el
 * contenido actual de BACKEND/src/modules/email/assets.
 *
 * Uso:
 *   npm run sync:email-assets:storage
 */
import fs from 'fs';
import path from 'path';
import { BACKEND_ROOT, loadBackendEnv } from './lib/postgres-env';

const ASSETS_DIR = path.join(BACKEND_ROOT, 'src', 'modules', 'email', 'assets');
const BUCKET = process.env.EMAIL_ASSETS_BUCKET?.trim() || 'email-assets';

interface AssetFile {
  localPath: string;
  remotePath: string;
}

function listPngFiles(dir: string, prefix = ''): AssetFile[] {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files: AssetFile[] = [];
  for (const entry of entries) {
    const localPath = path.join(dir, entry.name);
    const remotePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      files.push(...listPngFiles(localPath, remotePath));
    } else if (entry.name.toLowerCase().endsWith('.png')) {
      files.push({ localPath, remotePath });
    }
  }
  return files;
}

function storageHeaders(serviceKey: string, extra: Record<string, string> = {}): Record<string, string> {
  return {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    ...extra,
  };
}

async function ensureBucketPublic(baseUrl: string, serviceKey: string): Promise<void> {
  const bucketUrl = `${baseUrl}/storage/v1/bucket/${BUCKET}`;
  const existing = await fetch(bucketUrl, { headers: storageHeaders(serviceKey) });

  if (existing.status === 200) {
    const body = (await existing.json()) as { public?: boolean };
    if (body.public) {
      return;
    }
    const patch = await fetch(bucketUrl, {
      method: 'PUT',
      headers: storageHeaders(serviceKey, { 'Content-Type': 'application/json' }),
      body: JSON.stringify({ public: true }),
    });
    if (!patch.ok) {
      throw new Error(`No se pudo hacer público el bucket ${BUCKET}: ${await patch.text()}`);
    }
    console.log(`  bucket ${BUCKET}: pasado a público`);
    return;
  }

  if (existing.status !== 404) {
    throw new Error(`Error consultando bucket ${BUCKET}: ${existing.status} ${await existing.text()}`);
  }

  const created = await fetch(`${baseUrl}/storage/v1/bucket`, {
    method: 'POST',
    headers: storageHeaders(serviceKey, { 'Content-Type': 'application/json' }),
    body: JSON.stringify({
      id: BUCKET,
      name: BUCKET,
      public: true,
      file_size_limit: 2097152,
      allowed_mime_types: ['image/png'],
    }),
  });
  if (!created.ok) {
    throw new Error(`No se pudo crear el bucket ${BUCKET}: ${await created.text()}`);
  }
  console.log(`  bucket ${BUCKET}: creado (público)`);
}

async function uploadFile(baseUrl: string, serviceKey: string, file: AssetFile): Promise<void> {
  const bytes = fs.readFileSync(file.localPath);
  const res = await fetch(`${baseUrl}/storage/v1/object/${BUCKET}/${file.remotePath}`, {
    method: 'POST',
    headers: storageHeaders(serviceKey, {
      'Content-Type': 'image/png',
      'x-upsert': 'true',
    }),
    body: bytes,
  });
  if (!res.ok) {
    throw new Error(`Falló la subida de ${file.remotePath}: ${res.status} ${await res.text()}`);
  }
  console.log(`  ✓ ${file.remotePath} (${bytes.length} bytes)`);
}

export async function syncEmailAssetsToStorage(): Promise<{ publicBase: string; logoUrl: string }> {
  const supabaseUrl = process.env.SUPABASE_URL?.trim();
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

  if (!supabaseUrl || !serviceKey) {
    throw new Error(
      'Faltan SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY para subir assets de email a Storage.'
    );
  }
  if (!fs.existsSync(ASSETS_DIR)) {
    throw new Error(`No existe ${ASSETS_DIR}`);
  }

  console.log(`\n▶ Sincronizando assets de email → Supabase Storage (bucket "${BUCKET}")...`);
  await ensureBucketPublic(supabaseUrl, serviceKey);

  const logoPath = path.join(ASSETS_DIR, 'logo.png');
  if (!fs.existsSync(logoPath)) {
    throw new Error(`No existe ${logoPath}`);
  }
  const iconsDir = path.join(ASSETS_DIR, 'icons');
  const files: AssetFile[] = [
    { localPath: logoPath, remotePath: 'logo.png' },
    ...(fs.existsSync(iconsDir) ? listPngFiles(iconsDir, 'icons') : []),
  ];

  for (const file of files) {
    await uploadFile(supabaseUrl, serviceKey, file);
  }

  const publicBase = `${supabaseUrl.replace(/\/+$/, '')}/storage/v1/object/public/${BUCKET}`;
  const logoUrl = `${publicBase}/logo.png`;

  console.log(`\n✓ ${files.length} assets sincronizados`);
  console.log(`  EMAIL_LOGO_URL=${logoUrl}`);
  console.log(`  EMAIL_ASSETS_BASE_URL=${publicBase}`);
  console.log('  (deben coincidir con BACKEND/.env.staging y los secrets de Supabase)');

  return { publicBase, logoUrl };
}

if (require.main === module) {
  loadBackendEnv();
  syncEmailAssetsToStorage().catch((error) => {
    console.error(
      '\nsync:email-assets:storage falló:',
      error instanceof Error ? error.message : error
    );
    process.exit(1);
  });
}
