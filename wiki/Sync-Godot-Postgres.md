# Sync Godot ↔ PostgreSQL

> Junio 2026 · Ver también: [Arquitectura](Arquitectura-General.md)

El progreso se guarda en **dos lugares independientes**: disco local (`save_data.json`) y PostgreSQL (`completed_nodes`). El puente es una **cola offline** que reintenta la subida cuando el servidor vuelve a estar disponible. El local nunca se pisa con el remoto; siempre se hace un *merge* tomando el mejor resultado de cada lado.

---

## Capas

```
Godot
  ├─ Global (autoload)          ← estado en memoria
  ├─ SaveManager (autoload)     ← save_data.json + merge con servidor
  └─ BackendSession (autoload)  ← token JWT, HTTP, retry
       └─ ProgressSyncService   ← envía RunSummary al backend
            └─ LocalSyncQueue   ← backend_sync_queue.json (cola offline)

Node.js BACKEND
  ├─ POST /player/me/progress   ← recibe partida, persiste en Postgres
  └─ GET  /player/me/progress   ← devuelve progreso completo del usuario
```

---

## Flujos

### Login / restauración de sesión

1. `POST /auth/login` → recibe JWT → guarda token en disco → `reintentar_pendientes()`
2. `GET /user/me` + `GET /player/me/progress` → obtiene datos del servidor
3. `SaveManager.sincronizar_con_cuenta_online()`:
   - `linked_username == nuevo_usuario` → **merge** local + servidor (mismo usuario, conserva offline)
   - `linked_username != nuevo_usuario` → **reset** local, importa datos del nuevo usuario

Al reabrir el juego (sin login explícito), `_restaurar_sesion_guardada()` valida el token guardado en disco y repite el paso 2–3 automáticamente.

### Completar un nodo

1. `SaveManager.guardar_precision_nodo()` → escribe en `save_data.json` **inmediatamente** (`completed=true`, `best_accuracy=max(prev, nuevo)`)
2. `RunSummarySyncAdapter` construye un `RunSummary` y lo encola en `backend_sync_queue.json`
3. Si hay sesión activa → `POST /player/me/progress`:
   - ✓ marca ítem como `synced`, aplica `completedNodes` devueltos al save local
   - ✗ ítem queda `pending` para retry

**En Postgres (POST):** transacción atómica que hace upsert en `PROGRESO_RESTRICCION`, insert en `HISTORY_GAME`, upsert en `COMPLETED_NODES` (si `completed=true`), y actualiza racha. Idempotente por `clientRunId`.

### Cierre de sesión

1. `SyncApi.reintentar_pendientes()` → intenta vaciar la cola mientras el token sigue válido
2. `SaveManager.al_cerrar_sesion_online()` → guarda a disco **sin tocar** `node_progress` ni `linked_online_username`
3. `BackendSession.cerrar_sesion()` → borra token de memoria y disco

> `linked_online_username` se conserva al logout para que el mismo usuario recupere su progreso local en el próximo login y otro usuario dispare el reset.

### Retry de pendientes

Se ejecuta en: login exitoso · restauración de sesión · logout explícito.

```
ProgressSyncService.reintentar_pendientes()
  → lee status=pending de la cola (hasta 10 ítems)
  → POST /player/me/progress por cada uno
      ✓ → marcar_sincronizado()
      ✗ 401 → abort (sesión expirada)
      ✗ otro → marcar_fallido() (attempts++)
```

---

## Merge de nodos

`fusionar_node_progress(local, online)` — regla por campo:

| Campo | Resultado |
|---|---|
| `completed` | `local OR online` |
| `best_accuracy` / `best_percent` | `max(local, online)` |
| Nodo solo en local | se conserva (offline no se pierde) |
| Nodo solo en online | se agrega al local |
| `total_exp` | `max(local, online)` |
| racha | gana la de mayor `current_count` (empate: más reciente) |

---

## Archivos clave

| Archivo | Qué hace |
|---|---|
| `juego/API/AuthApi.gd` | Fachada: login, logout, cargar online |
| `juego/API/SyncApi.gd` | Fachada: sincronizar partida, retry |
| `juego/API/backend/session/BackendSession.gd` | Token, HTTP, restore, caché |
| `juego/API/backend/sync/ProgressSyncService.gd` | Envío HTTP + manejo 401 |
| `juego/API/backend/sync/RunSummarySyncAdapter.gd` | Construye RunSummary desde resultado |
| `juego/API/backend/sync/LocalSyncQueue.gd` | Cola offline en disco |
| `juego/API/backend/sync/ImportadorProgresoOnline.gd` | Traduce GET + merge |
| `juego/interface/SaveManager.gd` | Save local, merge, disco |
| `BACKEND/.../progreso-restriccion.service.ts` | Upsert nodo/EXP/racha en Postgres |

---

## Diagnóstico rápido

**Ver archivos locales (PowerShell):**
```powershell
cat "$env:APPDATA\Godot\app_userdata\Evidente\save_data.json" | python -m json.tool
cat "$env:APPDATA\Godot\app_userdata\Evidente\backend_sync_queue.json" | python -m json.tool
```

**Ver progreso en DB:**
```sql
SELECT u.username, cn.node_id, cn.best_accuracy
FROM completed_nodes cn
JOIN player_progress pp ON pp.id = cn.progress_id
JOIN users u ON u.id = pp.user_id
WHERE u.username = 'margo';
```

**Tabla de síntomas:**

| Síntoma | Causa probable |
|---|---|
| Nodo completado no aparece al re-entrar | Cola con `pending` o sync falló |
| Todos los nodos en gris al login | `_reiniciar_progreso` se disparó (ver `linked_online_username`) |
| EXP no sube | POST falló o `expToAdd=0` |
| Datos de otro usuario visibles | `linked_online_username` ≠ usuario logueado |
| Estrella gris en nodo completado | `best_percent` bajo (ver `LevelNode._actualizar_insignia`) |

**Forzar retry / reset debug (consola Godot):**
```gdscript
SyncApi.reintentar_pendientes()   # sube pendientes al servidor
SaveManager.reiniciar_todo_progreso()  # limpia local (no toca DB)
```

---

## Bugs resueltos

| Bug | Causa | Solución |
|---|---|---|
| Progreso perdido al logout | `al_cerrar_sesion_online` borraba `node_progress` y ponía `linked=""` | Ahora solo guarda a disco, sin limpiar nada |
| Precisión fija al 50%/100% | `pregunta.gd` y `vincular_conceptos.gd` hardcodeaban el valor | Usan `NodoRuntimeScript.calcular_precision()` |
| Estrella gris en nodo completado | `effective_progress = best_percent` (podía ser bajo) | Si `is_completed`, `effective_progress = 1.0` siempre |
| `completedNodes` del POST no aplicados | `_aplicar_racha_de_respuesta_sync` no los procesaba | Ahora llama `fusionar_completados_desde_sync()` |
