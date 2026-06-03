# Mapa del backend: de Godot a PostgreSQL

Este documento explica qué pasa por dentro cuando Godot sincroniza progreso con el backend. Está pensado para poder defender el flujo sin tener que abrir todos los archivos a la vez.

Endpoint principal:

```http
POST /player/me/progress
```

---

## Recorrido completo

```text
Godot
  manda RunSummary + JWT
        |
        v
Route: player.routes.ts
        |
        v
Middleware: authenticate_token.ts
        |
        v
Controller: player.controller.ts
        |
        v
Service: player.service.ts
        |
        v
Repository: player.repository.ts
        |
        v
PostgreSQL
        |
        v
Mapper: player.mapper.ts
        |
        v
Respuesta JSON para Godot
```

La responsabilidad está separada por capas. La ruta decide qué handler usar, el middleware valida identidad, el controller arma la llamada, el service aplica reglas de negocio, el repository habla con PostgreSQL y el mapper limpia la respuesta pública.

---

## 1. Route

Archivo: `BACKEND/src/modules/player/player.routes.ts`

La ruta del módulo player protege todos sus endpoints con `authenticateToken`. Eso evita repetir la validación de JWT en cada handler.

En este caso, `POST /me/progress` queda conectado a `postPlayerProgressController`.

---

## 2. Middleware de autenticación

Archivo: `BACKEND/src/modules/auth/authenticate_token.ts`

Este middleware lee el header:

```http
Authorization: Bearer TOKEN
```

Si el token es válido, agrega el usuario a `req.user`. Si no lo es, responde `401` y corta el flujo.

La parte importante para seguridad es que el `userId` no viene del body enviado por Godot. Viene del JWT verificado. Entonces un jugador no puede sincronizar progreso para otro usuario cambiando un campo en el JSON.

---

## 3. Controller

Archivo: `BACKEND/src/modules/player/player.controller.ts`

El controller hace poco a propósito:

- toma `userId` desde `req.user.id`;
- toma el body enviado por Godot;
- llama a `saveAuthenticatedProgress`;
- delega los errores a `sendError`.

No contiene reglas de negocio. Su rol es traducir HTTP hacia la capa de aplicación.

---

## 4. Service

Archivo: `BACKEND/src/modules/player/player.service.ts`

El service es donde vive la lógica del caso de uso. Valida los datos recibidos y decide cómo impactan en el progreso.

Validaciones principales:

| Campo | Regla |
|---|---|
| `restriction` | Obligatorio. Debe ser `CELIAQUIA`, `VEG`, `VYG` o `KETO`. |
| `accuracy` | Si viene, debe estar entre `0` y `100`. |
| `completed` | Si viene, debe ser booleano. |
| `correctAnswers` | Si viene, debe ser `>= 0`. |
| `wrongAnswers` | Si viene, debe ser `>= 0`. |
| `durationSeconds` | Si viene, debe ser `>= 0`. |
| `finishedAt` | Si viene, debe ser fecha ISO válida. |

Reglas de progreso:

- Una partida cuenta para `completed_games_count` solo si `completed` es `true`.
- Un nodo cuenta para `completed_nodes_count` solo la primera vez que se completa.
- En replays, el progreso no se duplica, pero sí puede mejorar el mejor puntaje o la mejor precisión.
- Si el nodo ya estaba completado, `completedNode` vuelve como `null` para avisarle a Godot que no fue una nueva completación.

---

## 5. Repository

Archivo: `BACKEND/src/modules/player/player.repository.ts`

El repository concentra las operaciones SQL. Para guardar progreso se tocan varias tablas porque una partida impacta en perfil, racha, progreso por restricción, sesión jugada y nodo completado.

| Operación | Tabla |
|---|---|
| Verificar usuario público | `users` |
| Sumar experiencia del perfil | `player_profiles` |
| Asegurar racha diaria | `player_streaks` |
| Crear o actualizar progreso por restricción | `player_progress` |
| Registrar la sesión jugada | `game_sessions` |
| Crear o actualizar nodo completado | `completed_nodes` |
| Consultar resumen actualizado | `player_progress`, `completed_nodes`, `unlocked_content`, `game_sessions` |

Para `completed_nodes`, el backend usa un UPSERT que conserva los mejores valores:

```sql
ON CONFLICT (progress_id, node_id)
DO UPDATE SET
  best_score = GREATEST(completed_nodes.best_score, EXCLUDED.best_score),
  best_accuracy = GREATEST(completed_nodes.best_accuracy, EXCLUDED.best_accuracy)
```

Antes del UPSERT se consulta si el nodo ya existía. Con eso se calcula `wasNew`, que después permite decidir si hay que incrementar `completed_nodes_count`.

---

## 6. Mapper

Archivo: `BACKEND/src/modules/player/player.mapper.ts`

El mapper prepara la respuesta pública. Expone datos útiles para Godot, pero no devuelve claves internas como `user_id` o `progress_id`.

En `gameSession`, por ejemplo, se exponen campos como:

```text
id, game_type, node_id, accuracy, score, completed,
started_at, completed_at, created_at,
correct_answers, wrong_answers, duration_seconds, finished_at
```

---

## Tablas involucradas

| Tabla | Para qué se usa |
|---|---|
| `users` | Confirmar que el usuario del token existe. |
| `player_profiles` | Mantener experiencia general del jugador. |
| `player_streaks` | Registrar racha diaria. |
| `player_progress` | Guardar avance por restricción. |
| `game_sessions` | Guardar cada partida sincronizada. |
| `completed_nodes` | Guardar nodos completados y mejores métricas. |
| `unlocked_content` | Armar el resumen de contenido desbloqueado. |

---

## Idea central

El backend no intenta reemplazar el guardado local de Godot. Recibe un resumen de lo que ya ocurrió en el juego y lo persiste de forma ordenada, asociada al usuario autenticado.

Eso permite que el juego siga siendo tolerante a fallos: si el backend no responde, Godot no pierde la partida; simplemente queda pendiente la sincronización.
