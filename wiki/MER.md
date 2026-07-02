# MER — Modelo de entidades y relaciones

Índice de diagramas por entrega. El proyecto usa **tres capas** que no deben mezclarse en un solo dibujo:

> **Vistas interactivas:** [Índice completo](Vistas-Interactivas) — se abren desde la wiki con un clic, sin descargar HTML.

| Capa | Qué modela | Vista interactiva |
|------|------------|-------------------|
| **Dominio** | Conceptos del juego (jugador, mapa, partida, modalidades, ítems) | [Mer-Dominio](Mer-Dominio) |
| **Persistencia** | Dónde se guarda el estado del jugador (local + PostgreSQL + email E4) | [Mer-Persistencia-E3](Mer-Persistencia-E3) · [Mer-Persistencia-E4](Mer-Persistencia-E4) |
| **Contenido** | Preguntas, mapas, ítems — archivos JSON en `juego/contenido/` | No es base de datos; ver [contenido/README](../juego/contenido/README.md) |

Hub visual: [Mer-Hub](Mer-Hub) · Evolución y flujos: [Mer-Flujo](Mer-Flujo) · Detalle sync: [Sync-Godot-Postgres](Sync-Godot-Postgres)

---

## Por entrega

### Entrega 1

Se documentó el **MER de dominio**: recorrido educativo desde el jugador hasta las modalidades y el catálogo de ítems. La persistencia era solo local (`user://save_data.json` vía `SaveManager`); no había PostgreSQL.

El diagrama fue diseñado en **Excalidraw** y refleja las entidades conceptuales del juego:

![MER Dominio E1/E2](Mer.png)

- Diagrama interactivo: [Mer-Dominio](Mer-Dominio)
- Fuente visual: `wiki/Mer.png` (Excalidraw original)
- Evidencia: [Entrega-1-Arquitectura](Entrega-1-Arquitectura)

### Entrega 2

**Sin cambios en MER ni persistencia.** La iteración fue polish visual, transiciones, Completar Palabra y tests de carga JSON. El dominio se extendió con una modalidad más (Completar Palabra); el diagrama de dominio la incluye con nota E2.

- Dominio: mismo esquema conceptual + Completar Palabra
- Persistencia: idéntica a E1 (solo save local)

### Entrega 3

Se agregó **persistencia remota** en PostgreSQL (`BACKEND/migrations/`) alineada al MER Excalidraw canónico, sin reemplazar el save local. Conviven:

1. **Local** — `save_data.json`, cola `backend_sync_queue.json`, sesión `backend_session.json`, avatares en disco.
2. **PostgreSQL** — `users` → `profiles` → `progress_restrictions` → `history_games` → `games`, más `streaks`, `images`, `restriction_node_config`.

- Diagrama dual: [Mer-Persistencia-E3](Mer-Persistencia-E3)
- Arquitectura: [Entrega-3-Arquitectura](Entrega-3-Arquitectura)

### Entrega 4

Se **extendió** el esquema E3 sin romper local-first ni el dominio conceptual. Se agregó el canal transaccional de mails sobre Supabase:

1. **PostgreSQL** — 2 tablas nuevas (`email_deliveries`, `email_verification_codes`) + 3 columnas en `users`.
2. **Supabase Edge** — `verify-email-*`, `internal-job`, secrets Brevo; `pg_cron` para jobs de racha.
3. **Godot** — `backend.local.json` con `api_mode=supabase_edge` (o `auto`); cache de `mail_verified_at` y opt-in en sesión/perfil. `save_data.json` sigue en v4.

- Diagrama E3+E4: [Mer-Persistencia-E4](Mer-Persistencia-E4)
- Narrativa: [Entrega-4](Entrega-4) · [Flujo E3→E4](Entrega-4-Flujo-E3-E4)

---

## PostgreSQL — esquema canónico E3 (código)

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

## PostgreSQL — extensión E4 (email)

Fuente: migraciones `021`, `022`, `023`, `028`, `037`. Implementación productiva en `supabase/functions/_shared/delivery.ts`.

```
users (columnas E4)
  ├── mail_verified_at
  ├── email_notifications_enabled
  └── welcome_email_sent_at
  ├── email_deliveries (1:N) — auditoría Brevo
  │     template_key · dedupe_key · status · provider_message_id
  └── email_verification_codes (1:N) — OTP
        code_hash · target_mail · expires_at · failed_attempt_count
```

| Tabla / columna | Rol |
|-----------------|-----|
| `users.mail_verified_at` | Mail confiable antes de welcome y recordatorios |
| `users.email_notifications_enabled` | Opt-in recordatorios de racha |
| `users.welcome_email_sent_at` | Marca post-envío welcome |
| `email_deliveries` | Outbox + dedupe + retry (`pending`→`sent`/`failed`/`skipped`) |
| `email_verification_codes` | OTP de 6 dígitos (hash, no plaintext) |

Jobs: `pg_cron` → Edge `internal-job` (`streak-at-risk-emails`, `streak-lost-emails`, `retry-failed-emails`).

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
| `backend_session.json` | JWT + cache usuario (`mail_verified_at`, notificaciones) |
| `backend.local.json` | `api_mode`, URL Edge, `db=supabase` (gitignored, sync desde BACKEND) |
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
| Mail verificado (E4) | cache en `backend_session` | `users.mail_verified_at` + `email_verification_codes` |
| Opt-in notificaciones (E4) | `profile.email_notifications_enabled` | `users.email_notifications_enabled` |
| Auditoría mail (E4) | — (no local) | `email_deliveries` |
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
