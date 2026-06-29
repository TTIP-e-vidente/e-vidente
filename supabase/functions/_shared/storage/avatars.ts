import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

const BUCKET = 'avatars';

export class StorageConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'StorageConfigError';
  }
}

let cachedClient: SupabaseClient | null = null;

function storageClient(): SupabaseClient {
  if (cachedClient) {
    return cachedClient;
  }
  const url = Deno.env.get('SUPABASE_URL')?.trim();
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim();
  if (!url || !key) {
    throw new StorageConfigError('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for avatar storage');
  }
  cachedClient = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return cachedClient;
}

export function isAvatarStorageConfigured(): boolean {
  return Boolean(
    Deno.env.get('SUPABASE_URL')?.trim() && Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim(),
  );
}

export function avatarObjectPath(userId: string, mimeType: string): string {
  const ext = mimeType === 'image/jpeg' ? 'jpg' : mimeType === 'image/webp' ? 'webp' : 'png';
  return `${userId}/avatar.${ext}`;
}

export async function uploadAvatarBytes(
  userId: string,
  bytes: Uint8Array,
  mimeType: string,
): Promise<string> {
  const path = avatarObjectPath(userId, mimeType);
  const { error } = await storageClient().storage.from(BUCKET).upload(path, bytes, {
    upsert: true,
    contentType: mimeType,
  });
  if (error) {
    throw new Error(`avatar storage upload failed: ${error.message}`);
  }
  return path;
}

export async function downloadAvatarBytes(storagePath: string): Promise<Uint8Array | null> {
  const { data, error } = await storageClient().storage.from(BUCKET).download(storagePath);
  if (error || !data) {
    return null;
  }
  return new Uint8Array(await data.arrayBuffer());
}

export async function deleteAvatarObject(storagePath: string): Promise<void> {
  const { error } = await storageClient().storage.from(BUCKET).remove([storagePath]);
  if (error) {
    console.warn(`[avatar-storage] delete failed for ${storagePath}: ${error.message}`);
  }
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export function base64ToBytes(data: string): Uint8Array {
  const binary = atob(data);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
