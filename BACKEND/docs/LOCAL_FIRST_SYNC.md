# Sync local-first de progreso

La demo funciona sin backend: el save local (`SaveManager`) es la fuente de
verdad offline y la nube es un espejo idempotente.

## Piezas

| Lado | Pieza | Rol |
|---|---|---|
| Godot | `SincronizadorPartida.gd` | arma el RunSummary post-partida y genera el `clientRunId` |
| Godot | `LocalSyncQueue.gd` | cola persistente (`user://backend_sync_queue.json`), multi-cuenta por `owner`, máx. 5 intentos por ítem |
| Godot | `ProgressSyncService.gd` | batch de hasta 50 ítems, ordenado por `finishedAt`, retry cada 5 min |
| Edge/Express | `player-progress-batch` | merge idempotente + estado consolidado |

## Idempotencia

- **`clientRunId` es obligatorio** por ítem del batch (ítems sin él se rechazan
  individualmente con `error: "clientRunId es requerido"`).
- Constraint: `UNIQUE(progress_id, client_run_id)` en `games` (migración 007).
- Reintentar el mismo batch (timeout, corte de red) **no duplica** EXP,
  sesiones ni nodos: el server detecta el `clientRunId` existente y lo reporta
  como duplicado.
- Advisory lock por `userId` serializa escrituras concurrentes.

## Respuesta del batch

```json
{
  "synced": true,
  "processed": 2,
  "createdSessions": 2,
  "ignoredDuplicates": 0,
  "results": [{ "clientRunId": "...", "ok": true, "duplicate": false, "data": {...} }],
  "summary": { "total": 2, "synced": 2, "failed": 0 },
  "progressSummary": { "user": ..., "profile": ..., "streak": ..., "progress": [...], "completedNodes": [...] },
  "progress": [...],
  "streak": {...}
}
```

`results`/`summary`/`progressSummary` se mantienen por compatibilidad con el
cliente Godot existente; `synced/processed/createdSessions/ignoredDuplicates/
progress/streak` son los campos nuevos del contrato V1.

## Reglas de merge

- `best_score` / `best_accuracy`: máximo (upsert de `completed_nodes`).
- `completed_nodes`: unión (`UNIQUE(progress_id, node_id)`).
- Racha: por **día local del jugador** (`localDay`), auto-curativa
  (ver `docs-local` y migración 019). El batch se aplica ordenado por
  `finishedAt` para no romperla.
- EXP: solo suma en runs nuevos (los duplicados no suman).

## Offline

- Sin sesión: las partidas quedan encoladas con `owner=""` y se sincronizan al
  loguear. Sin internet: quedan `pending`; el timer de 5 min y el próximo login
  las drenan. Un 401 a mitad de batch deja los ítems restantes `pending` (no
  se marcan fallidos).
- Cambio de cuenta: los pendientes del usuario saliente se archivan por owner
  y se restauran cuando vuelve (sin mezclar cuentas).

## Tests

- `tests/progress.batch-idempotency.integration.test.ts` — reintento sin
  duplicar EXP, `ignoredDuplicates`, `clientRunId` obligatorio.
- Godot: `juego/tests/progress/test_racha_sync.gd` (merge de racha, existente).
