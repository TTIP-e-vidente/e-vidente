# Sync Godot ↔ PostgreSQL

Documentación del equipo · Junio 2026

El juego guarda progreso en dos lugares: el disco del cliente (`save_data.json`) y PostgreSQL. Cuando no hay conexión o el POST falla, las partidas quedan en una cola local (`backend_sync_queue.json`) y se reintentan automáticamente. El cliente no reemplaza el save local con lo que viene del servidor: hace merge campo por campo (completado, precisión, EXP, racha).

---

## Modelo de datos

```
users
  └── profiles          ← hub: FK user, FK streak, EXP global
        └── progress_restrictions   ← progreso por restricción (ej. celiaquía)
              └── history_games     ← estado de cada nodo del mapa
                    └── games       ← cada partida individual
```

| Entidad | Rol |
|---|---|
| `profiles` | Agrupa la info del jugador: usuario, racha actual, EXP total |
| `progress_restrictions` | Progreso agregado de una restricción (`total_exp`, `completed_nodes_count`, `map_completed`) |
| `history_games` | Un registro por nodo: si está completado, mejor score/precisión, cuándo |
| `games` | Cada intento en un nodo (con `client_run_id` para idempotencia) |

La API devuelve `completedNodes[]` en el response; internamente lo lee desde `history_games` (nodos con `completed = true`).

---

## Archivos locales

En Godot, `user://` mapea a:

```
%APPDATA%\Godot\app_userdata\Evidente\
```

| Código | Disco |
|---|---|
| `user://save_data.json` | progreso del jugador |
| `user://backend_sync_queue.json` | cola de partidas pendientes de subir |
| `user://backend_session.json` | JWT guardado entre sesiones |
| `user://avatars/{usuario}.{ext}` | fotos de perfil, una por cuenta |

Para inspeccionar en PowerShell:

```powershell
cd "$env:APPDATA\Godot\app_userdata\Evidente"
type backend_sync_queue.json
```

Si la cola no existe, es normal: se crea la primera vez que termina un minijuego.

Desde el editor de Godot:

```gdscript
print(ProjectSettings.globalize_path("user://backend_sync_queue.json"))
```

---

## Flujo completo: partida terminada

1. `SaveManager.guardar_precision_nodo` → escribe `save_data.json` al instante.
2. `SincronizadorPartida.sincronizar_post_partida` → construye un `RunSummary` con `clientRunId` único y lo encola con `LocalSyncQueue.encolar_resumen_partida`.
3. Si no hay sesión → queda `pending`, se reintenta cuando vuelva a loguearse.
4. Si hay sesión → `SyncApi.reintentar_pendientes()` → `BackendSession.reintentar_sync_pendiente()`.
5. `ProgressSyncService.reintentar_pendientes` arma un array con todos los `payload` pendientes y hace **un solo POST** a `/player/me/progress/batch`.
6. El backend procesa cada ítem en su propia transacción y devuelve `results[]` indexado por `clientRunId`.
7. Al terminar, escribe todos los resultados a disco en un solo paso (`LocalSyncQueue.aplicar_resultados`).
8. Si alguno sincronizó exitosamente → `limpiar_cola` elimina los viejos del historial.
9. `BackendSession._aplicar_racha_de_respuesta_sync` mergea racha y `completedNodes` de la respuesta al save local.

---

## Componentes

```
Godot
  SaveManager              → save_data.json, merge, perfil
  Global                   → estado en memoria de la partida actual
  BackendSession           → JWT, cache de datos online, background sync
  SyncApi / AuthApi        → punto de entrada desde el juego
  SincronizadorPartida     → arma payload y encola
  LocalSyncQueue           → backend_sync_queue.json + cache en memoria
  ProgressSyncService      → batch POST y retry
  BackendApiClient         → HTTP con pool de nodos reutilizados
  ImportadorProgresoOnline → traduce GET del servidor al formato local

Backend (Node.js)
  POST /player/me/progress          ← un solo RunSummary (legacy, sigue existiendo)
  POST /player/me/progress/batch    ← array de RunSummary (sync de cola)
  GET  /player/me/progress
  POST /player/me/avatar            ← sube foto en base64
  GET  /player/me/avatar
  GET  /auth/me
```

Desde el juego se usan casi siempre solo `AuthApi` y `SyncApi`.

---

## Retry automático

Hay tres mecanismos que disparan el retry, en orden de prioridad:

**1. Inmediato (al terminar una partida)**
`SincronizadorPartida` llama `SyncApi.reintentar_pendientes()` ni bien encola el ítem, si hay sesión activa.

**2. Dirty-flag (concurrencia de triggers)**
Si `reintentar_sync_pendiente()` se llama mientras un sync está corriendo, en vez de ignorarlo levanta un flag (`_reintento_encolado`). Cuando termina el sync actual, si hay ítems nuevos, arranca otro round automáticamente.

**3. Background timer (cada 5 minutos)**
`BackendSession._ready()` crea un `Timer` de 300 segundos. Si hay ítems `pending` y el usuario está logueado y no está sincronizando, dispara `reintentar_pendientes()`.

También se reintenta en login, restauración de sesión y, como último intento, al cerrar sesión.

---

## Cola local (`LocalSyncQueue`)

Cada ítem tiene:

| Campo | Qué es |
|---|---|
| `clientRunId` | ID único generado en el cliente |
| `status` | `pending` / `synced` / `failed` |
| `attempts` | cuántas veces se intentó |
| `lastError` | último error (máx 500 chars) |
| `createdAt` | cuándo se encoló |
| `syncedAt` | cuándo se sincronizó |
| `payload` | el RunSummary completo |

Después de 5 intentos fallidos (`MAX_ATTEMPTS = 5`) el ítem pasa a `failed` y se deja de reintentar. Sigue en disco como historial.

**Pruning automático** (se ejecuta tras cada sync exitoso):
- `synced` con más de 7 días → se elimina
- `failed` con más de 30 días → se elimina

La cola tiene un cache en memoria para evitar leer el JSON a cada llamada. Se invalida cuando se escribe.

---

## Ejemplo de cola

```json
{
  "items": [
    {
      "clientRunId": "run_20260606110000_1234567890_42",
      "status": "pending",
      "attempts": 1,
      "lastError": "Sin conexión",
      "createdAt": "2026-06-06T11:00:00",
      "syncedAt": "",
      "payload": {
        "restriction": "celiaquia",
        "nodeId": "celiaquia_nodo_3",
        "accuracy": 85,
        "completed": true
      }
    }
  ]
}
```

Cuando el batch responde 200, cada ítem exitoso pasa a `"status": "synced"` y se completa `syncedAt`. Si el batch entero falla (red caída, 401, etc.), todos los ítems quedan `pending` para el próximo retry.

---

## Sync batch (`POST /player/me/progress/batch`)

Desde junio 2026 la cola ya no hace un POST por partida. Envía todos los pendientes en un request:

```json
{
  "items": [
    { "clientRunId": "run_...", "restriction": "celiaquia", "nodeId": "...", "accuracy": 85, "completed": true },
    { "clientRunId": "run_...", "restriction": "celiaquia", "nodeId": "...", "accuracy": 90, "completed": true }
  ]
}
```

Respuesta:

```json
{
  "results": [
    { "clientRunId": "run_...", "ok": true, "data": { "...": "..." } },
    { "clientRunId": "run_...", "ok": false, "error": "..." }
  ],
  "summary": { "total": 2, "synced": 1, "failed": 1 }
}
```

Detalles:
- Máximo **50 ítems** por batch.
- Cada ítem corre `saveAuthenticatedProgress()` en su propia transacción (mismo advisory lock por usuario).
- Un ítem fallido no cancela los demás.
- Si la respuesta HTTP falla por completo, la cola no marca nada como sincronizado.

---

## Qué hace el backend en Postgres

`saveAuthenticatedProgress()` corre en una transacción:

1. Valida JWT.
2. `pg_advisory_xact_lock` por `userId` — serializa saves concurrentes del mismo usuario (dos sesiones abiertas en simultáneo).
3. Si `clientRunId` ya existe en `games` → devuelve estado actual sin insertar nada (idempotencia).
4. Suma EXP en `profiles`.
5. Upsert en `progress_restrictions` por restricción.
6. Upsert en `history_games` por `(progress_id, node_id)` con CTE + `FOR UPDATE` para derivar `wasNewlyCompleted` de manera atómica. Actualiza mejor score/precisión.
7. Insert en `games` con el `history_id` del nodo (incluye `local_day`: el día calendario del jugador en su huso, que manda el cliente).
8. Si completó → recalcula `streaks` desde los días con partidas completadas. El día relevante es `games.local_day` (fallback: día UTC de `finished_at` para partidas viejas). También persiste `last_activity_at`: el instante real de la última partida completada.
9. Devuelve snapshot: profile, streak, progress, completedNodes, recentGames.

El advisory lock garantiza que si dos dispositivos suben progreso del mismo usuario al mismo tiempo, uno espera al otro. El que llega primero gana; el segundo ve el estado ya actualizado.

---

## HTTP (`BackendApiClient`)

Los nodos `HTTPRequest` se guardan en un pool (`_pool: Array[HTTPRequest]`) en vez de crearlos y destruirlos por cada request. El timeout por defecto es de 3 segundos; la subida de avatar usa 30 segundos.

---

## Avatar de perfil

Además del progreso, la foto de perfil se sincroniza por separado.

**Postgres:**

```
users.avatar_image_id  →  images (data base64, mime_type, user_id UNIQUE)
```

**Local:** cada cuenta tiene su archivo en `user://avatars/{username}.{png|jpg|webp}`. La clave sale de la sesión online activa, no de un nombre genérico compartido.

**Flujo:**

1. El jugador elige foto → `SaveManager` copia a `user://avatars/{usuario}.ext`.
2. Si hay sesión → `POST /player/me/avatar` con `{ data, mimeType }`.
3. Al login / cargar datos online → `GET /player/me/avatar` si el archivo local no existe o la ruta no corresponde al usuario logueado.
4. Al cambiar de cuenta (`linked_online_username` ≠ username nuevo) → se limpia `avatar_path` del perfil y se descarga la foto del usuario entrante.

Subida desde: pantalla de perfil (`auth.gd`), botón "Guardar ahora" del overlay, y al abrir perfil si ya hay foto local pendiente de sync.

---

## Login y cambio de usuario

1. `POST /auth/login` → guarda token.
2. `reintentar_pendientes()` → intenta vaciar la cola al tiro.
3. `GET /auth/me` y `GET /player/me/progress` en secuencia.
4. `SaveManager.sincronizar_con_cuenta_online()`:
   - Mismo usuario que `linked_online_username` → merge local + servidor.
   - Usuario distinto → backup del progreso anterior, reset local, **limpiar avatar**, importar progreso del nuevo.

`linked_online_username` en `save_data.json` indica con qué cuenta quedó vinculado el save local. Se conserva al cerrar sesión para que al volver el mismo usuario recupere su progreso offline.

---

## Reglas de merge

**Nodos** (`fusionar_node_progress`):
- `completed` = local OR online
- `best_accuracy` / `best_percent` = máximo
- Si el nodo solo está en un lado, se conserva ese lado

**EXP:** `max(local, online)`

**Racha** (`fusionar_estado_racha`):
- Gana la de mayor `current_count`
- Empate → gana la de `last_activity_day` más reciente

La racha cuenta **días calendario locales del jugador**, no días UTC. El badge (verde/rojo) se deriva de `last_activity_at` (instante UTC real de la última partida, expuesto por el server) convertido al huso local. `updated_at` de `streaks` es la hora del último sync y **no** debe usarse como señal de actividad: ese fue el bug que dejaba la racha "activa hoy" sin haber jugado.

---

## Idempotencia (`clientRunId`)

Cada partida tiene un ID único (`run_<timestamp>_<ms>_<rand>`). Si se reenvía el mismo resumen:
- La cola del cliente no lo duplica (chequea `clientRunId` antes de encolar).
- El servidor detecta la partida ya guardada y no inserta nada.

---

## Archivos relevantes

| Archivo | Rol |
|---|---|
| `juego/interface/SaveManager.gd` | Save local, merge, login/logout |
| `juego/API/SyncApi.gd` | Fachada de sync |
| `juego/API/AuthApi.gd` | Login / logout |
| `juego/API/backend/http/BackendApiClient.gd` | HTTP + pool |
| `juego/API/backend/session/BackendSession.gd` | JWT, cache online, background sync, dirty-flag |
| `juego/API/backend/sync/SincronizadorPartida.gd` | Arma RunSummary y encola |
| `juego/API/backend/sync/LocalSyncQueue.gd` | Cola en disco + cache en memoria |
| `juego/API/backend/sync/ProgressSyncService.gd` | Batch POST y retry |
| `juego/API/backend/sync/ImportadorProgresoOnline.gd` | GET → formato local |
| `BACKEND/src/modules/progreso-restriccion/progreso-restriccion.service.ts` | Persistencia en Postgres |
| `BACKEND/src/modules/image/image.controller.ts` | Avatar POST/GET |

---

## Diagnóstico

**Cola y save local:**

```powershell
type "$env:APPDATA\Godot\app_userdata\Evidente\backend_sync_queue.json"
type "$env:APPDATA\Godot\app_userdata\Evidente\save_data.json"
```

**Avatar en Postgres:**

```sql
SELECT u.username, u.avatar_image_id, i.mime_type, length(i.data) AS data_len, i.updated_at
FROM users u
LEFT JOIN images i ON i.id = u.avatar_image_id
WHERE u.username IN ('agus', 'margo');
```

**Script de diagnóstico (backend):**

```powershell
cd BACKEND
node scripts/check-sync-status.js
```

**Nodos completados en Postgres:**

```sql
SELECT u.username, pr.restriction, hg.node_id, hg.best_accuracy, hg.best_score, hg.completed
FROM history_games hg
JOIN progress_restrictions pr ON pr.id = hg.progress_id
JOIN profiles p ON p.id = pr.profile_id
JOIN users u ON u.id = p.user_id
WHERE u.username = 'margo'
  AND hg.completed = true;
```

**Forzar retry desde consola Godot:**

```gdscript
SyncApi.reintentar_pendientes()
```

**Tabla de síntomas:**

| Síntoma | Qué revisar |
|---|---|
| Nodo completado no aparece al re-entrar | ítems `pending` en la cola; log del POST en consola |
| Progreso de otro usuario | `linked_online_username` en `save_data.json` |
| EXP no sube | `expToAdd` en el payload; respuesta del POST |
| Racha incorrecta al login | orden del merge en `_importar_progreso_online` |
| Ítem con `status: failed` | llegó a 5 intentos; revisar `lastError` |
| Avatar de otro usuario | `avatar_path` en save; archivo en `user://avatars/`; re-login fuerza descarga |
| Batch no drena cola | consola Godot: respuesta de `/player/me/progress/batch`; backend levantado |

---

## Notas

- Al cambiar de usuario se hace backup de `node_progress` por username antes del reset.
- La racha local se lee **antes** de pisar `save_data.progress` en el import online; si no, el merge pierde el valor local.
- En logout no se borra `node_progress` ni `linked_online_username`.
- Mapas no implementados (`VEG`, `VYG`, `KETO`) tienen `total_nodes = 9999` en `restriction_node_config` para que `map_completed` nunca se active prematuramente.
