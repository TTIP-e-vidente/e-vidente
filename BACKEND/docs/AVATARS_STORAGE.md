# Avatares: Storage privado + fallback legacy

## Reglas de negocio

- Bucket **`avatars`** privado (migración 034: `public=false`,
  `file_size_limit=3 MB`, MIME `image/png|jpeg|webp`). Solo lo toca el
  **service_role desde las Edge Functions** — el cliente nunca habla con
  Storage directo y **no puede elegir el path**.
- Path canónico calculado por el backend: **`{userId}/avatar.{ext}`**
  (`ext`: `png` | `jpg` | `webp`).
- Nunca se persisten signed URLs: `images.storage_path` es la verdad de negocio
  y los bytes se resuelven on-demand en `avatar-get`/`avatar-public`.
- Cache busting: `images.updated_at` (viaja como `updatedAt` en las respuestas).
- Nota sobre RLS: los usuarios finales usan JWT propio (no Supabase Auth), por
  lo que **no aplican policies `auth.uid()`** en `storage.objects`. La defensa
  es: bucket privado + acceso exclusivo vía Edge con service_role + RLS
  lockdown del schema public (migración 030).

## Validación (Edge `_shared/services/avatar.ts` y Express `image.controller.ts`)

| Regla | Error |
|---|---|
| MIME ∉ {png, jpeg, webp} | 400 `AVATAR_UNSUPPORTED_MIME` |
| base64 > 4 MB o bytes reales > 3 MB | 413 `AVATAR_TOO_LARGE` |
| base64 inválido | 400 `INVALID_BODY` |

## Flujo de upload (Edge)

```
cliente → { data: base64, mimeType }
  ├─ Storage configurado:
  │    ├─ upload OK → images: { storage_path, data=NULL, mime_type, updated_at }
  │    ├─ upload FALLA + AVATAR_BASE64_FALLBACK=true (default)
  │    │    → images: { data=base64 legacy, storage_path=NULL }
  │    └─ upload FALLA + fallback deshabilitado → 503 STORAGE_UNAVAILABLE
  │    └─ upload OK pero UPDATE de images falla → se borra el objeto subido
  └─ Storage no configurado → base64 legacy en images.data
```

## Cliente Godot

- Upload: `BackendSession.subir_avatar`. Si falla por red/5xx se registra en
  `AvatarSyncService.marcar_subida_pendiente` (archivo
  `user://avatars/pending_upload.json`) y el avatar local **no se pierde**.
- Al siguiente login (`_sincronizar_avatar_post_login`):
  - hay subida pendiente → se reintenta el upload (lo local gana);
  - si no → `_descargar_avatar_si_falta` con **reintentos** (inmediato, +5 s,
    +15 s) solo ante fallas de red/5xx.
- Cambio de cuenta a mitad de descarga: se descarta por epoch (no se pisa el
  avatar de otra cuenta).

## Tests

- `tests/avatar.integration.test.ts` — MIME/size/upload/get/public/delete.
- Godot: `juego/tests/backend/test_platform_v1_cliente.gd` — marcador de subida
  pendiente por cuenta y detección de MIME.

## Probar manualmente

1. Subir un PNG < 3 MB desde el perfil → cerrar y reabrir el juego → el avatar
   persiste (descarga on-demand).
2. Cortar internet, cambiar el avatar → queda local + marcado pendiente →
   reconectar y reloguear → se sube solo.
3. Intentar subir un GIF o > 3 MB → error claro sin crash.
