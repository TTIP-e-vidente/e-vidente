# Contrato RunSummary: Godot -> Backend

Este documento deja asentado qué información manda Godot al backend cuando termina una partida o un nodo. La idea es que el juego pueda seguir funcionando localmente, como siempre, y que el backend reciba un resumen suficiente para reconstruir progreso, sesiones jugadas, precisión, experiencia y nodos completados.

El contrato ya está implementado en `POST /player/me/progress`.

---

## Endpoint

```http
POST /player/me/progress
Authorization: Bearer TOKEN
Content-Type: application/json
```

El endpoint requiere sesión activa. Si no hay token, Godot no debería bloquear el juego: simplemente conserva el progreso local y, cuando aplique, deja el resumen pendiente para sincronizar más tarde.

---

## Body que envía Godot

```json
{
  "restriction": "CELIAQUIA",
  "nodeId": "celiaquia_01_desayuno_basico",
  "gameType": "quiz",
  "score": 120,
  "accuracy": 85,
  "correctAnswers": 17,
  "wrongAnswers": 3,
  "expToAdd": 25,
  "completed": true,
  "durationSeconds": 90,
  "finishedAt": "2026-06-02T15:00:00.000Z",
  "clientRunId": "run_20260602T150000_123_4567"
}
```

### Campos

| Campo | Tipo | Regla |
|---|---|---|
| `restriction` | `string` | Obligatorio. Uno de `CELIAQUIA`, `VEG`, `VYG`, `KETO`. |
| `nodeId` | `string` | ID del nodo del mapa. |
| `gameType` | `string` | Modalidad jugada: quiz, completar, vinculación, arrastre, etc. |
| `score` | `number` | Puntaje de la partida. Si falta, se toma como `0`. |
| `accuracy` | `number` | Porcentaje entre `0` y `100`. |
| `correctAnswers` | `number` | Cantidad de aciertos. Debe ser `>= 0`. |
| `wrongAnswers` | `number` | Cantidad de errores. Debe ser `>= 0`. |
| `expToAdd` | `number` | Experiencia a sumar. Si falta, se toma como `0`. |
| `completed` | `boolean` | `true` si la partida o nodo se terminó correctamente. |
| `durationSeconds` | `number` | Duración de la partida en segundos. |
| `finishedAt` | `string` | Fecha ISO generada por el cliente. |
| `clientRunId` | `string` | ID único local para evitar duplicar una misma corrida al reintentar sync. |

---

## Respuesta exitosa

El backend responde `201` con el estado actualizado:

```json
{
  "user": { "...": "..." },
  "profile": { "exp_count": 125 },
  "streak": { "current_count": 3 },
  "progress": {
    "restriction_type": "CELIAQUIA",
    "total_exp": 125,
    "completed_games_count": 5,
    "completed_nodes_count": 2
  },
  "gameSession": {
    "node_id": "celiaquia_01_desayuno_basico",
    "score": 120,
    "accuracy": "85",
    "completed": true
  },
  "completedNode": {
    "node_id": "celiaquia_01_desayuno_basico",
    "best_score": 120,
    "best_accuracy": "85"
  },
  "summary": { "...": "..." }
}
```

`completedNode` puede venir en `null` si ese nodo ya estaba completado. En ese caso no se cuenta como una nueva completación, pero el backend sí puede mejorar `best_score` o `best_accuracy` si la nueva partida fue mejor.

---

## Reglas de negocio importantes

- `completed_games_count` sube solo cuando `completed` es `true`.
- `completed_nodes_count` sube solo la primera vez que un nodo se completa.
- `best_score` nunca baja: se conserva el mejor puntaje.
- `best_accuracy` nunca baja: se conserva la mejor precisión.
- `finishedAt` viene desde Godot; `completed_at` lo pone el servidor.
- `clientRunId` permite reintentar una sincronización sin duplicar experiencia, sesiones ni nodos completados.

---

## Errores esperados

| Status | Caso |
|---|---|
| `400` | Falta `restriction` o viene una restricción inválida. |
| `400` | `accuracy` está fuera de `0..100`. |
| `400` | Aciertos, errores o duración vienen con valores negativos. |
| `400` | `finishedAt` no es una fecha ISO válida. |
| `400` | `completed` no es booleano. |
| `401` | Token faltante, inválido o vencido. |
| `500` | Error inesperado del servidor. |

---

## Estado actual

El backend ya soporta todos los campos necesarios para la primera integración con Godot: progreso por restricción, sesiones de juego, nodos completados, métricas de precisión, experiencia y reintentos idempotentes por `clientRunId`.

La decisión de diseño más importante es que el backend es una capa adicional, no una dependencia para jugar. Si falla la red, la sesión o el servidor, el guardado local sigue siendo la fuente inmediata de continuidad para el jugador.
