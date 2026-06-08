# MER — Modelo de entidades y relaciones

Índice de diagramas por entrega. El proyecto usa **tres capas** que no deben mezclarse en un solo dibujo:

| Capa | Qué modela | Diagrama |
|------|------------|----------|
| **Dominio** | Conceptos del juego (jugador, mapa, partida, modalidades, ítems) | [mer-dominio.html](mer-dominio.html) |
| **Persistencia** | Dónde se guarda el estado del jugador (local + PostgreSQL) | [mer-persistencia-e3.html](mer-persistencia-e3.html) |
| **Contenido** | Preguntas, mapas, ítems — archivos JSON en `juego/contenido/` | No es base de datos; ver [contenido/README](../juego/contenido/README.md) |

Hub interactivo: [mer.html](mer.html) · Detalle operativo sync: [Sync-Godot-Postgres](Sync-Godot-Postgres)

---

## Por entrega

### Entrega 1

Se documentó el **MER de dominio**: recorrido educativo desde el jugador hasta las modalidades y el catálogo de ítems. La persistencia era solo local (`user://save_data.json` vía `SaveManager`); no había PostgreSQL.

- Diagrama: [mer-dominio.html](mer-dominio.html)
- Evidencia: [Entrega-1-Arquitectura](Entrega-1-Arquitectura)

### Entrega 2

**Sin cambios en MER ni persistencia.** La iteración fue polish visual, transiciones, Completar Palabra y tests de carga JSON. El dominio se extendió con una modalidad más (Completar Palabra); el diagrama de dominio la incluye con nota E2.

- Dominio: mismo esquema conceptual + Completar Palabra
- Persistencia: idéntica a E1 (solo save local)

### Entrega 3

Se agregó **persistencia remota** en PostgreSQL (`BACKEND/migrations/`) alineada al MER Excalidraw canónico, sin reemplazar el save local. Conviven:

1. **Local** — `save_data.json`, cola `backend_sync_queue.json`, sesión `backend_session.json`, avatares en disco.
2. **PostgreSQL** — `users` → `profiles` → `progress_restrictions` → `history_games` → `games`, más `streaks`, `images`, `restriction_node_config`.

- Diagrama dual: [mer-persistencia-e3.html](mer-persistencia-e3.html)
- Arquitectura: [Entrega-3-Arquitectura](Entrega-3-Arquitectura)

---

## PostgreSQL — esquema canónico (código)

Fuente: migraciones `002`, `008`, `009`, `010`, `011`, `015`, `016`. Tablas legacy (`player_*`, `game_sessions`, `completed_nodes`, `unlocked_content`) eliminadas en `008`.

```
users
  ├── profiles (1:1 user_id)
  │     ├── streak_id → streaks
  │     └── progress_restrictions (1:N por restriction)
  │           └── history_games (1 registro por nodo: UNIQUE progress_id + node_id)
  │                 └── games (cada intento / RunSummary)
  ├── avatar_image_id → images (1 avatar por user_id)
restriction_node_config (config de total_nodes por restricción — no FK al jugador)
```

| Tabla | Rol en código |
|-------|----------------|
| `users` | Auth JWT; `username`, `name`, `mail`, `password_hash`, `birth_date` |
| `profiles` | Hub del jugador; `exp_count`, `current_restriction`, `streak_id` |
| `streaks` | Racha diaria; referenciada desde `profiles.streak_id` |
| `progress_restrictions` | Progreso por pista (`CELIAQUIA`, `VEG`, …); agregados y `map_completed` |
| `history_games` | Estado por nodo del mapa (`node_id`, `best_accuracy`, `completed`) |
| `games` | Partida individual; `client_run_id` para idempotencia |
| `images` | Avatar base64; `users.avatar_image_id` |
| `restriction_node_config` | `total_nodes` por restricción (30 celiaquía; 9999 centinela en otras) |

Servicio: `BACKEND/src/modules/progreso-restriccion/progreso-restriccion.service.ts` (`saveAuthenticatedProgress`).

---

## Save local — esquema canónico (código)

Fuente: `SaveDataSchema.gd` (versión 4), `SaveManager.gd`, `ImportadorProgresoOnline.gd`.

| Campo `save_data.json` | Rol |
|------------------------|-----|
| `version` | Esquema actual = 4 |
| `profile` | Identidad local (`username`, `birth_date`, `email`, `avatar_path`) |
| `node_progress` | Dict por `node_id`: `completed`, `best_accuracy`, `best_percent` |
| `progress` | Campaña por track + `progress_system_states` (racha, `question_progress`) |
| `total_exp` | EXP acumulada |
| `resume_state` | Dónde reanudar (`hub`, `libro`, nivel) |
| `save_meta` | `linked_online_username`, timestamps de escritura |
| `played_activity_ids` / `completed_activity_ids` | Trazabilidad de actividades |

Archivos adicionales en `user://`:

| Archivo | Rol |
|---------|-----|
| `backend_sync_queue.json` | Cola de `RunSummary` pendientes (`LocalSyncQueue.gd`) |
| `backend_session.json` | JWT entre sesiones (`BackendSession.gd`) |
| `avatars/{username}.ext` | Avatar por cuenta online |

---

## Mapeo dominio → persistencia

| Concepto dominio | Local | PostgreSQL |
|------------------|-------|------------|
| Jugador | runtime + `profile` | `users` |
| Perfil | `save_data.profile` + `total_exp` | `profiles` |
| Racha | `progress.progress_system_states.streak` | `streaks` |
| Progreso (por restricción) | `node_progress` + flags de campaña | `progress_restrictions` |
| Nodo del mapa completado | `node_progress[node_id]` | `history_games` |
| Intento de partida | payload en cola sync | `games` |
| Avatar | `profile.avatar_path` + archivo | `images` + `users.avatar_image_id` |
| Mapa / Partida / Modalidades | `juego/contenido/mapa/*.json` | **No persistido** (solo estado del jugador) |
| Item / Condición alimentaria | `items_celiaquia.json` + `.tres` | **No persistido** |

Traducción servidor → local: `ImportadorProgresoOnline.construir_snapshot_local()`.

Sync local → servidor: `SincronizadorPartida` → `ProgressSyncService` → `POST /player/me/progress/batch`.

---

## Contenido (fuera del MER de persistencia)

El mapa y las actividades no viven en ninguna base de datos:

```
juego/contenido/mapa/celiaquia_mapa.json  → nodos + games
juego/contenido/mapa/preguntas.json       → quiz
juego/contenido/mapa/arrastres.json       → drag_food
juego/contenido/mapa/vinculaciones.json   → match
juego/contenido/mapa/completar_palabra.json
juego/contenido/catalogos/items_celiaquia.json
```

Flujo: `CargadorDeMapa` → `ArmadorDePartida` → `NodeContentLoader` → minijuego.
