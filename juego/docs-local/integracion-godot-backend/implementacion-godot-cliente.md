# Implementación Godot: cliente backend

Este documento resume cómo quedó integrada la primera capa de comunicación entre Godot y el backend. La integración se diseñó con una regla clara: el backend suma persistencia remota, pero nunca bloquea el juego.

El guardado local sigue siendo la primera línea de continuidad. La sincronización remota ocurre después, en segundo plano, y puede fallar sin romper la partida.

---

## Archivos principales

```text
juego/project/backend/
├── BackendApiClient.gd
├── AuthSession.gd
├── BackendSession.gd
├── BackendSessionStorage.gd
├── LocalSyncQueue.gd
├── ProgressSyncService.gd
├── RunSummaryBuilder.gd
├── RunSummarySyncAdapter.gd
└── dev/
    ├── BackendConnectionSmoke.gd
    └── BackendSessionSmoke.gd
```

| Archivo | Rol |
|---|---|
| `BackendApiClient.gd` | Único archivo que hace HTTP. Usa `HTTPRequest`, parsea JSON y devuelve `{ ok, status, data }`. |
| `AuthSession.gd` | Guarda el token JWT y los datos básicos de sesión en memoria. |
| `BackendSession.gd` | Autoload público. Las escenas hablan con este archivo, no con HTTP directo. |
| `BackendSessionStorage.gd` | Persiste una sesión mínima en `user://backend_session.json`. |
| `LocalSyncQueue.gd` | Guarda resúmenes pendientes cuando no se puede sincronizar. |
| `ProgressSyncService.gd` | Orquesta el envío de progreso y emite señales de sync. |
| `RunSummaryBuilder.gd` | Construye el body que espera el backend. |
| `RunSummarySyncAdapter.gd` | Traduce el cierre real de una partida a `RunSummary`. |

---

## Decisión de arquitectura

La integración está armada como una capa lateral al gameplay.

Las escenas y sistemas de juego no necesitan saber cómo se arma una request HTTP ni cómo se guarda un token. Solo llaman a `BackendSession` o dejan que el adapter sincronice al terminar una partida.

Se evitó tocar piezas sensibles:

- `SaveManager.gd` sigue guardando local.
- Los minijuegos no hacen HTTP.
- `MapScene`, HUD y pantallas de gameplay no dependen del backend.
- Si no hay sesión, red o servidor, el flujo jugable continúa.

---

## BackendSession como fachada

`BackendSession.gd` está registrado como Autoload:

```ini
BackendSession="*res://project/backend/BackendSession.gd"
```

Desde cualquier escena se puede usar así:

```gdscript
if BackendSession.is_logged_in():
    var progress := await BackendSession.get_progress()

var login_result := await BackendSession.login(username, password)
```

Métodos principales:

| Método | Uso |
|---|---|
| `login(user, pass)` | Inicia sesión y guarda token. |
| `register(user, name, mail, pass, age)` | Crea cuenta y deja sesión activa si el backend devuelve token. |
| `logout()` | Limpia sesión en memoria y en disco. |
| `get_me()` | Consulta usuario autenticado. |
| `get_progress()` | Consulta progreso remoto. |
| `save_progress(run_summary)` | Intenta sincronizar una partida. |
| `load_account_data()` | Recupera usuario y progreso para cache interno. |

Señales principales:

| Señal | Cuándo se emite |
|---|---|
| `login_succeeded(user)` | Login o registro exitoso. |
| `login_failed(reason)` | Falló la autenticación. |
| `logout_completed()` | Se cerró sesión. |
| `session_restored(user)` | Se restauró una sesión guardada. |
| `session_restore_failed(reason)` | Había token guardado, pero ya no era válido. |
| `sync_started()` | Comenzó una sincronización. |
| `sync_succeeded(progress)` | El backend aceptó el progreso. |
| `sync_failed(reason)` | Falló la sync, pero el juego sigue. |
| `session_expired()` | El backend respondió `401`; se limpia la sesión. |

---

## Flujo al tocar Jugar

En el menú principal:

```text
Jugador toca "Jugar"
        |
        v
¿Hay sesión activa?
   | sí
   v
Continuar al selector

   | no
   v
Mostrar Login
   | login correcto
   v
Recuperar perfil y progreso
   |
   v
Continuar al selector

   | jugar offline
   v
Continuar al selector sin token
```

El backend es opcional. Si está apagado o la autenticación falla, el jugador puede elegir "Jugar sin iniciar sesión".

---

## Login

Archivos:

```text
juego/project/auth/Login.gd
juego/project/auth/Login.tscn
```

La pantalla permite:

- iniciar sesión con usuario o mail y contraseña;
- crear una cuenta nueva;
- continuar offline;
- mostrar mensajes claros si falla la conexión o las credenciales.

El login se muestra como overlay desde `intro.gd`, dentro de un `CanvasLayer`. Esa decisión evita el problema de anclar un `Control` directamente debajo de un `Node2D`, que hacía que el panel apareciera mal posicionado.

Señales usadas por el menú:

```gdscript
signal login_completed()
signal play_offline_requested()
```

Ambas llevan al selector. La diferencia es que `login_completed` deja una sesión activa y `play_offline_requested` continúa sin token.

---

## Persistencia de sesión

La sesión mínima se guarda en:

```text
user://backend_session.json
```

Formato:

```json
{
  "token": "eyJhbGci...",
  "username": "agus",
  "user": { "id": "...", "username": "agus" },
  "savedAt": "2026-06-02T15:30:00"
}
```

No se guarda la contraseña.

Al iniciar Godot, `BackendSession` intenta restaurar la sesión. Si el token todavía sirve, emite `session_restored`. Si el backend responde `401` o el archivo está corrupto, limpia la sesión y el juego arranca offline.

Para esta etapa, guardar el token en texto plano en `user://` se considera aceptable para demo y desarrollo local. No es una solución final de producción.

---

## Sincronización al terminar una partida

El punto de integración está en:

```text
juego/niveles/progress/PostGameFlowController.gd
```

El orden buscado es:

```text
1. Se calcula el resultado de la partida.
2. SaveManager guarda progreso local.
3. RunSummarySyncAdapter arma el resumen.
4. BackendSession intenta sincronizar.
5. La navegación continúa sin esperar al backend.
```

Ese orden es importante. El jugador no debería perder progreso por un problema de red.

---

## RunSummarySyncAdapter

`RunSummarySyncAdapter.gd` traduce datos del cierre de partida al contrato backend.

Mapeo principal:

| Campo backend | Fuente en Godot |
|---|---|
| `restriction` | `resultado.map_id` |
| `nodeId` | `resultado.node_key` |
| `gameType` | modo actual de la sesión de juego |
| `score` | aciertos o puntaje calculado |
| `accuracy` | precisión del nodo |
| `correctAnswers` | aciertos |
| `wrongAnswers` | errores |
| `expToAdd` | experiencia ganada |
| `completed` | resultado de la partida |
| `durationSeconds` | duración medida |
| `clientRunId` | ID único generado localmente |

Si faltan métricas, usa valores seguros (`0`, `false` o identificadores fallback). La sync puede quedar menos rica, pero no rompe.

---

## Cola local de sincronización

Cuando el backend no está disponible, `LocalSyncQueue` guarda el resumen en:

```text
user://backend_sync_queue.json
```

Después, `ProgressSyncService.retry_pending()` puede reintentar esos envíos al iniciar sesión, restaurar sesión o cuando se dispare un nuevo intento de sync.

Cada partida lleva `clientRunId`, por lo que reintentar no debería duplicar experiencia ni sesiones en el backend.

---

## Perfil

Archivos:

```text
juego/project/player/Profile.gd
juego/project/player/Profile.tscn
```

La pantalla de perfil consulta `GET /player/me/progress` mediante `BackendSession.get_progress()`.

Muestra:

- usuario;
- experiencia;
- racha actual y mejor racha;
- partidas completadas;
- nodos completados;
- cantidad de sesiones recientes.

Si no hay sesión, muestra un mensaje claro. Si el backend falla, no afecta el juego.

---

## Feedback post-partida

En la pantalla de finalización se agregó feedback mínimo de sincronización:

- si el backend responde bien: "Sincronizado con tu cuenta";
- si falla la red o no hay conexión: "Sin conexión: se sincronizará más tarde";
- si no hay sesión: se mantiene el guardado local.

El feedback es informativo. No cambia el resultado de la partida.

---

## Cómo probar

### Backend local

```powershell
cd BACKEND
npm run dev
```

### Smoke de sesión

En Godot, ejecutar:

```text
res://project/backend/dev/BackendSessionSmoke.gd
```

Debe probar:

1. login o registro;
2. `get_me`;
3. armado de RunSummary;
4. `save_progress`;
5. `get_progress`;
6. logout.

### Flujo real

1. Abrir el juego.
2. Tocar "Jugar".
3. Iniciar sesión o elegir "Jugar sin iniciar sesión".
4. Completar un minijuego.
5. Confirmar que el guardado local ocurre siempre.
6. Si hay sesión y backend activo, confirmar que se sincroniza.

---

## Deudas conocidas

- Persistencia de token lista para demo, pero no endurecida para producción.
- Algunas métricas tienen fallbacks cuando no llegan desde el runtime.
- La migración histórica de partidas locales anteriores no es completa porque `SaveManager` no guarda todos los detalles necesarios de cada partida.
- A futuro conviene normalizar `gameType` a un catálogo único de modalidades.

---

## Resumen

La integración deja al juego en un punto sano: se puede jugar offline, se guarda local primero y, cuando hay cuenta disponible, el progreso se sincroniza con backend. La capa HTTP está encapsulada, el gameplay no queda acoplado al servidor y los errores de red se tratan como una condición normal, no como una falla fatal.
