# Evidencia — Entrega 3

> Sync con Jira: **10 jun 2026** · [proyecto UNQ](https://tip-unq.atlassian.net/jira/software/projects/UNQ/boards).

## Evidencia por user story

| US | Descripción | Tickets | Estado |
|---|---|---|---|
| US-01 | Infra PostgreSQL | UNQ-85, 87, 162, 161 | En revisión (161 ✅) |
| US-02 | Registro y login | UNQ-65, 171, 90, 91 | Listo — 4/4 terminados |
| US-03 | Sync de progreso | UNQ-160, 163 | En revisión |
| US-04 | Perfil dedicado | UNQ-107, 27 | En curso (107 ✅) |
| US-05 | Nodo único de partida | UNQ-170 | En revisión |
| US-06 | Enseñanzas JSON | UNQ-167, 168 | En curso (167 ✅) |
| US-07 | Test UX Preguntas | UNQ-172 | En progreso |
| US-08 | Borde comidas | UNQ-166 | Terminado |

Epic del sprint: [UNQ-8](https://tip-unq.atlassian.net/browse/UNQ-8). Total: 17 tickets, 8 historias.

## Tickets Jira

| Clave | Resumen | US | Estado Jira |
|---|---|---|---|
| [UNQ-85](https://tip-unq.atlassian.net/browse/UNQ-85) | Configurar PostgreSQL local con Docker | US-01 | Revisión |
| [UNQ-87](https://tip-unq.atlassian.net/browse/UNQ-87) | Validar conexión inicial con PostgreSQL | US-01 | Revisión |
| [UNQ-162](https://tip-unq.atlassian.net/browse/UNQ-162) | Modelar entidades principales del jugador | US-01 | Revisión |
| [UNQ-161](https://tip-unq.atlassian.net/browse/UNQ-161) | Identificar datos locales críticos a migrar | US-01 | Terminado |
| [UNQ-65](https://tip-unq.atlassian.net/browse/UNQ-65) | Diseñar registro de usuario | US-02 | Terminado |
| [UNQ-171](https://tip-unq.atlassian.net/browse/UNQ-171) | Diseñar pantalla de login | US-02 | Terminado |
| [UNQ-90](https://tip-unq.atlassian.net/browse/UNQ-90) | Implementar registro de usuario | US-02 | Terminado |
| [UNQ-91](https://tip-unq.atlassian.net/browse/UNQ-91) | Implementar login de usuario | US-02 | Terminado |
| [UNQ-160](https://tip-unq.atlassian.net/browse/UNQ-160) | Migrar y sincronizar progreso local | US-03 | Revisión |
| [UNQ-163](https://tip-unq.atlassian.net/browse/UNQ-163) | Guardar resumen de partida | US-03 | Revisión |
| [UNQ-107](https://tip-unq.atlassian.net/browse/UNQ-107) | Diseñar pantalla de perfil | US-04 | Terminado |
| [UNQ-27](https://tip-unq.atlassian.net/browse/UNQ-27) | Implementar escena de perfil | US-04 | En progreso |
| [UNQ-170](https://tip-unq.atlassian.net/browse/UNQ-170) | Nodo único multi-modalidad | US-05 | Revisión |
| [UNQ-167](https://tip-unq.atlassian.net/browse/UNQ-167) | Diseñar feedback enseñanzas | US-06 | Terminado |
| [UNQ-168](https://tip-unq.atlassian.net/browse/UNQ-168) | Feedback enseñanzas JSON | US-06 | En progreso |
| [UNQ-172](https://tip-unq.atlassian.net/browse/UNQ-172) | Test UX/UI Preguntas | US-07 | En progreso |
| [UNQ-166](https://tip-unq.atlassian.net/browse/UNQ-166) | Borde blanco en comidas | US-08 | Terminado |

**JQL:** `key in (UNQ-85, UNQ-87, UNQ-162, UNQ-161, UNQ-65, UNQ-171, UNQ-90, UNQ-91, UNQ-160, UNQ-163, UNQ-107, UNQ-27, UNQ-170, UNQ-167, UNQ-168, UNQ-172, UNQ-166) ORDER BY key ASC`

## Evidencia técnica en código

| Bloque | Archivos o módulos | Cómo probar |
|---|---|---|
| Docker / migraciones | `BACKEND/docker-compose.yml`, `BACKEND/migrations/` | `docker compose up -d` en `BACKEND/` |
| Auth backend | `BACKEND/src/modules/auth/` | POST register/login (curl o Postman) |
| Auth Godot | `juego/API/AuthApi.gd`, `juego/interface/auth.gd` | Intro → Registro / Login |
| Offline | flujo Intro sin backend | “Jugar sin iniciar sesión” → selector |
| Sync | `ProgressSyncService.gd`, `SyncApi.gd`, `ImportadorProgresoOnline.gd` | Jugar offline → login → verificar merge |
| Cola offline | `SaveManager.gd` | Apagar backend, terminar partida, volver a encender |
| Perfil / avatar | `BACKEND/src/modules/profile/`, overlay en mapa | Editar perfil y subir imagen con sesión |
| Nodo único | `MapBoard.gd`, JSON del mapa | Partida con ≥2 modalidades en celiaquía |
| Enseñanzas | scripts modalidad + JSON | Agregar entrada sin tocar GDScript |
| Tests Preguntas | `juego/tests/preguntas/test_modalidad_preguntas_ux_ui.gd` | GdUnit4 |
| Smoke CI | `juego/tests/vertical_slice_smoke_test.gd` | Workflow Gameplay Smoke en PR |

Documentación de sync: [Sync-Godot-Postgres](Sync-Godot-Postgres). Diagramas: [Mer-Persistencia-E3](Mer-Persistencia-E3), [MER](MER).

## Evidencia de CI

Workflows en [CI.md](CI.md):

| Workflow | Qué valida |
|---|---|
| Docs / Tracking | Bitácora y trazabilidad en PR |
| Technical Health | Estructura mínima del monorepo |
| Gameplay Smoke | Intro → login/offline → selector → mapa → partida |

## Evidencia de commits

Muestra representativa. Trazabilidad completa en git log y [Bitacora-Entrega-3](Bitacora-Entrega-3).

| Commit | Descripción | Ticket(s) |
|---|---|---|
| `c3e9d0a` | Setup Docker PostgreSQL (#32) | UNQ-85 |
| `65bf2f1` | Encaminando Entrega 3 (#31) | Infra / mapa |
| `28e1d0b` | AuthApi, SyncApi e importador | US-02, US-03 |
| `eb35afa` / `51eae03` | Sync local ↔ online | UNQ-160 |
| `4def73a` | Login actualizado | UNQ-91 |
| `3f458a0` | MapApi, nomenclatura ES | US-05 |
| `80690ab` | Smoke test actualizado | CI |
| `b8e80e8` | Pool HTTP, cola y background sync | US-03 |
| `2e5a9e9` | Avatar de usuario | US-04 |
| `82a38cd` | Badge de racha con fecha local | US-03 |
