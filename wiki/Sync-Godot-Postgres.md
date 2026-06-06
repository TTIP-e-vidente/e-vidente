# Sync Godot ↔ PostgreSQL

Documentación del equipo · Junio 2026

El juego guarda progreso en dos lugares: el disco del cliente (`save_data.json`) y PostgreSQL en el servidor. Cuando no hay conexión o falla el POST, las partidas quedan en una cola local (`backend_sync_queue.json`) y se reintentan al volver a loguearse.

El cliente no reemplaza el save local con lo que viene del servidor: hace merge campo por campo (completado, precisión, EXP, racha).

---

## Modelo de datos (Excalidraw)

Jerarquía pensada para ser eficiente y alineada al diagrama:

```
users
  └── profiles          ← hub: FK user, FK streak, EXP global
        └── progress_restrictions   ← progreso por restricción (ej. celiaquía)
              └── history_games     ← estado de cada nodo del mapa de esa restricción
                    └── games       ← cada partida jugada en ese nodo
```

| Entidad | Rol |
|---|---|
| `profiles` | Agrupa la info del jugador: usuario, racha actual (`streak_id`), EXP total |
| `progress_restrictions` | Progreso agregado de una restricción alimenticia (`total_exp`, `completed_nodes_count`, `map_completed`) |
| `history_games` | Un registro por nodo del mapa: si está completado, mejor score/precisión, cuándo |
| `games` | Cada intento/partida en un nodo (con `client_run_id` para idempotencia) |

La API sigue devolviendo `completedNodes[]` en JSON; internamente se lee desde `history_games` (nodos con `completed = true`).

---

## Dónde están los archivos locales

En Godot, `user://` es una carpeta del sistema operativo. No está dentro del repo del proyecto.

En Windows, con el juego compilado o corrido desde el editor con nombre **Evidente**:

```
%APPDATA%\Godot\app_userdata\Evidente\
```

Ahí aparecen, entre otros:

| Archivo en código | Archivo en disco |
|---|---|
| `user://save_data.json` | `save_data.json` |
| `user://backend_sync_queue.json` | `backend_sync_queue.json` |
| `user://backend_session.json` | `backend_session.json` (token JWT) |

Para verlos en PowerShell:

```powershell
cd "$env:APPDATA\Godot\app_userdata\Evidente"
dir
type backend_sync_queue.json
type save_data.json
```

Si el archivo de cola no existe todavía, es normal: se crea la primera vez que termina un minijuego y se encola algo para subir.

Desde la consola de Godot también se puede resolver la ruta:

```gdscript
print(ProjectSettings.globalize_path("user://backend_sync_queue.json"))
```

---

## Cómo funciona la sync (visión general)

1. El jugador termina un nodo → `SaveManager` escribe en `save_data.json` al momento.
2. `SincronizadorPartida` arma un resumen de partida (`RunSummary`) con un `clientRunId` único.
3. Ese resumen se guarda en `backend_sync_queue.json` con estado `pending`.
4. Si hay sesión activa, se hace `POST /player/me/progress`.
5. Si el POST responde bien → el ítem pasa a `synced` y se actualiza el save local con lo que devolvió el servidor.
6. Si falla o no hay login → queda `pending` y se reintenta en login, restore de sesión o logout.

Al loguearse, además del paso 4–6, el cliente descarga `GET /player/me/progress` y mergea con el save local.

---

## Componentes

```
Godot
  SaveManager          → save_data.json, merge, perfil
  Global               → estado en memoria de la partida actual
  BackendSession       → JWT, HTTP, caché de progreso online
  SyncApi / AuthApi    → entrada desde el juego
  SincronizadorPartida → arma payload y encola
  LocalSyncQueue       → backend_sync_queue.json
  ProgressSyncService  → POST y retry
  ImportadorProgresoOnline → traduce GET del servidor al formato local

Backend (Node.js)
  POST /player/me/progress
  GET  /player/me/progress
```

Desde el juego, lo habitual es llamar solo a `AuthApi` y `SyncApi`.

---

## Completar un nodo

**1. Guardado local** (`SaveManager.guardar_precision_nodo`):

- `completed = true`
- `best_accuracy = max(anterior, nuevo)`
- escribe `save_data.json`

**2. Resumen para el servidor** (`SincronizadorPartida.sincronizar_post_partida`):

Campos principales del payload:

| Campo | De dónde sale |
|---|---|
| `clientRunId` | generado en el cliente (`run_<fecha>_<ms>_<rand>`) |
| `restriction` | mapa / pista (ej. `celiaquia`) |
| `nodeId` | id del nodo en el mapa |
| `gameType` | modalidad del minijuego |
| `accuracy`, `score`, `expToAdd` | resultado de la partida |
| `completed` | si terminó bien |

**3. Cola** (`LocalSyncQueue.encolar_resumen_partida`):

Cada ítem tiene `clientRunId`, `status` (`pending` / `synced`), `attempts`, `payload`.

**4. POST** (si hay sesión):

`POST /player/me/progress` con JWT.

**5. Respuesta:**

`BackendSession` toma `summary.completedNodes` y `summary.streak` del response y los mergea al save local sin pisar valores mejores que ya tenía el cliente.

---

## Login y cambio de usuario

1. `POST /auth/login` → guarda token.
2. `reintentar_pendientes()` → intenta vaciar la cola.
3. `GET /user/me` y `GET /player/me/progress`.
4. `SaveManager.sincronizar_con_cuenta_online()`:

- Mismo usuario que `linked_online_username` → merge local + servidor.
- Usuario distinto → backup del progreso anterior, reset local, importar progreso del usuario nuevo.

El campo `save_meta.linked_online_username` indica con qué cuenta quedó vinculado el save local. Se conserva al cerrar sesión para que al volver el mismo usuario recupere su progreso offline.

### Importar progreso online (`_importar_progreso_online`)

Orden simplificado:

1. Traducir `completedNodes[]` del servidor a `node_progress{}`.
2. Si hay backup del usuario, mergearlo con el local.
3. Mergear `node_progress` local vs online.
4. `total_exp = max(local, online)`.
5. Leer racha local **antes** de sobreescribir `save_data.progress`.
6. Mergear racha y escribir a disco.

---

## Cierre de sesión

1. `reintentar_pendientes()` (último intento de subir la cola).
2. `SaveManager.al_cerrar_sesion_online()` → guarda disco, no borra `node_progress`.
3. `BackendSession.cerrar_sesion()` → borra el token.

---

## Retry de la cola

`ProgressSyncService.reintentar_pendientes()` lee hasta 10 ítems `pending` y hace POST por cada uno.

- OK → `marcar_sincronizado`
- 401 → corta, sesión inválida
- otro error → `marcar_fallido`, `attempts++`, sigue `pending`

---

## Qué hace el backend en Postgres

`saveAuthenticatedProgress()` corre en transacción:

1. Valida JWT.
2. Si `clientRunId` ya existe en `games` → devuelve estado actual (no duplica).
3. Suma EXP en `profiles`.
4. Upsert en `progress_restrictions` (por restricción).
5. Upsert en `history_games` por `(progress_id, node_id)` — mejor score/precisión, `completed`.
6. Insert en `games` apuntando al `history_id` del nodo.
7. Si completó → actualiza `streaks` y enlaza desde `profiles.streak_id`.
8. Devuelve snapshot: profile, streak, progress, completedNodes, recentGames.

### Tablas en Postgres (MER)

| Diagrama | Tabla |
|---|---|
| USER | `users` |
| IMAGE | `images` |
| PROFILE | `profiles` |
| STREAK | `streaks` |
| PROGRESO_RESTRICCION | `progress_restrictions` |
| HISTORY_GAME | `history_games` (progreso por nodo del mapa) |
| GAME | `games` (partidas individuales) |

---

## Reglas de merge

### Nodos (`fusionar_node_progress`)

Por cada `node_id`:

- `completed` = local OR online
- `best_accuracy` / `best_percent` = máximo de ambos
- Si el nodo solo está en un lado, se conserva ese lado

### EXP

`total_exp = max(local, online)`

### Racha (`fusionar_estado_racha`)

- Gana la de mayor `current_count`
- Empate → gana la de `last_activity_day` más reciente

---

## Idempotencia (`clientRunId`)

Cada partida tiene un ID único. Si se reenvía el mismo resumen:

- En el cliente, la cola no duplica el mismo `clientRunId`.
- En el servidor, `findGameByClientRunId` detecta la partida ya guardada y no inserta de nuevo.

---

## Ejemplo: cola offline

`backend_sync_queue.json` en disco:

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

Cuando el POST sale bien, ese ítem pasa a `"status": "synced"` y `syncedAt` se completa.

---

## Archivos de código relevantes

| Archivo | Rol |
|---|---|
| `juego/interface/SaveManager.gd` | Save local, merge, login/logout |
| `juego/API/SyncApi.gd` | Fachada de sync |
| `juego/API/AuthApi.gd` | Login / logout |
| `juego/API/backend/sync/SincronizadorPartida.gd` | Arma resumen y encola |
| `juego/API/backend/sync/LocalSyncQueue.gd` | Cola en disco |
| `juego/API/backend/sync/ProgressSyncService.gd` | HTTP POST y retry |
| `juego/API/backend/sync/ImportadorProgresoOnline.gd` | GET → formato local |
| `juego/API/backend/session/BackendSession.gd` | Sesión y token |
| `BACKEND/src/modules/progreso-restriccion/progreso-restriccion.service.ts` | Persistencia en Postgres |

---

## Diagnóstico

**Ver cola y save (PowerShell):**

```powershell
type "$env:APPDATA\Godot\app_userdata\Evidente\backend_sync_queue.json"
type "$env:APPDATA\Godot\app_userdata\Evidente\save_data.json"
```

**Ver nodos en Postgres:**

```sql
SELECT u.username, pr.restriction, hg.node_id, hg.best_accuracy, hg.completed
FROM history_games hg
JOIN progress_restrictions pr ON pr.id = hg.progress_id
JOIN profiles p ON p.id = pr.profile_id
JOIN users u ON u.id = p.user_id
WHERE u.username = 'margo'
  AND hg.completed = true;
```

**Consola Godot (debug):**

```gdscript
SyncApi.reintentar_pendientes()
```

| Síntoma | Qué revisar |
|---|---|
| Nodo completado no aparece al re-entrar | `backend_sync_queue.json` con ítems `pending`; logs del POST |
| Progreso de otro usuario | `linked_online_username` en `save_data.json` |
| EXP no sube | payload con `expToAdd`; respuesta del POST |
| Racha incorrecta al login | merge de racha; orden en `_importar_progreso_online` |

---

## Notas de implementación

- Al cambiar de usuario se hace backup de `node_progress` por username antes del reset.
- `clientRunId` evita duplicar partidas si hay retry o pérdida de red.
- La racha local se lee antes de pisar `save_data.progress` en el import online; si no, el merge pierde el valor local.
- En logout no se borra `node_progress` ni `linked_online_username`.
