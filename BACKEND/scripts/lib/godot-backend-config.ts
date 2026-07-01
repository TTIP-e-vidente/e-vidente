export type GodotApiMode = 'local' | 'cloud' | 'supabase_edge';
export type GodotDbKind = 'local' | 'supabase';

export interface StorageNamespaceInput {
  db: GodotDbKind;
  apiMode: GodotApiMode;
  envFile: string;
  baseUrl: string;
}

function sanitizeNamespacePart(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/^\.+/, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
}

export function buildStorageNamespace(input: StorageNamespaceInput): string {
  const dbPart = input.db === 'supabase' ? 'supabase' : 'local';
  const envPart = sanitizeNamespacePart(input.envFile) || sanitizeNamespacePart(input.baseUrl);
  return `${dbPart}-${envPart || input.apiMode}`;
}
