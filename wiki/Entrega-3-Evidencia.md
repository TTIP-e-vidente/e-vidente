# Evidencia — Entrega 3

> Entrega en curso. Estados alineados al sprint activo en Jira (jun 2026).

## Evidencia por user stories

| US | Descripción | Estado |
|---|---|---|
| US-01 | Infraestructura PostgreSQL (Docker, conexión, modelo, relevamiento) | En revisión — UNQ-161 terminado |
| US-02 | Registro y login con diseño de pantallas | En revisión |
| US-03 | Migración y sync de progreso + resumen de partida | En revisión |
| US-04 | Pantalla de perfil dedicada | Pendiente |
| US-05 | Nodo único de partida multi-modalidad | En revisión |
| US-06 | Enseñanzas y feedback por JSON | En curso |
| US-07 | Test automatizado UX/UI modalidad Preguntas | En curso |
| US-08 | Borde blanco en comidas | Terminada |

## Evidencia técnica en código

| Bloque | Archivos o módulos relacionados | Estado |
|---|---|---|
| Backend API | `BACKEND/src/modules/auth/`, `BACKEND/src/modules/player/`, `BACKEND/migrations/` | Confirmado por código |
| Cliente Godot API | `juego/API/backend/`, `juego/interface/auth.gd` | Confirmado por código |
| Sync de progreso | `ProgressSyncService`, cola local, `SyncApi` | Confirmado por código |
| Mapa en curva | `juego/mapas/layout/`, `MapBoard.gd`, `celiaquia_mapa.json` | Confirmado por código |
| Smoke test | `juego/tests/vertical_slice_smoke_test.gd` | Confirmado por CI |
| CI monorepo | `.github/workflows/`, `scripts/ci/check-monorepo-infra.ps1` | Confirmado por CI |
| Tests UX Preguntas | `juego/tests/preguntas/test_modalidad_preguntas_ux_ui.gd` | En curso |
| Assets comidas | sprites con borde (UNQ-166) | Confirmado por demo |

## Evidencia de CI

Workflows activos documentados en [CI.md](CI.md):

- **Docs / Tracking** — bitácora y trazabilidad en PR.
- **Technical Health** — estructura mínima del monorepo.
- **Gameplay Smoke** — flujo Intro → Login → offline → Selector → mapa.

## Tickets Jira del sprint

Fuente: [tip-unq.atlassian.net](https://tip-unq.atlassian.net) — proyecto UNQ, sprint abierto (17 issues).

| Clave | Resumen | Estado |
|---|---|---|
| [UNQ-160](https://tip-unq.atlassian.net/browse/UNQ-160) | Migrar y sincronizar progreso local | Revisión |
| [UNQ-163](https://tip-unq.atlassian.net/browse/UNQ-163) | Guardar resumen de partida | Revisión |
| [UNQ-85](https://tip-unq.atlassian.net/browse/UNQ-85) | PostgreSQL Docker | Revisión |
| [UNQ-162](https://tip-unq.atlassian.net/browse/UNQ-162) | Modelar entidades jugador | Revisión |
| [UNQ-161](https://tip-unq.atlassian.net/browse/UNQ-161) | Datos locales críticos | Terminado |
| [UNQ-167](https://tip-unq.atlassian.net/browse/UNQ-167) | Diseñar feedback enseñanzas | Revisión |
| [UNQ-87](https://tip-unq.atlassian.net/browse/UNQ-87) | Validar conexión PostgreSQL | Revisión |
| [UNQ-170](https://tip-unq.atlassian.net/browse/UNQ-170) | Nodo único multi-modalidad | Revisión |
| [UNQ-166](https://tip-unq.atlassian.net/browse/UNQ-166) | Borde blanco comidas | Terminado |
| [UNQ-65](https://tip-unq.atlassian.net/browse/UNQ-65) | Diseñar registro | Revisión |
| [UNQ-91](https://tip-unq.atlassian.net/browse/UNQ-91) | Implementar login | Revisión |
| [UNQ-90](https://tip-unq.atlassian.net/browse/UNQ-90) | Implementar registro | Revisión |
| [UNQ-171](https://tip-unq.atlassian.net/browse/UNQ-171) | Diseñar pantalla login | Revisión |
| [UNQ-172](https://tip-unq.atlassian.net/browse/UNQ-172) | Test UX/UI Preguntas | En progreso |
| [UNQ-168](https://tip-unq.atlassian.net/browse/UNQ-168) | Feedback enseñanzas JSON | En progreso |
| [UNQ-107](https://tip-unq.atlassian.net/browse/UNQ-107) | Diseñar perfil | Por Hacer |
| [UNQ-27](https://tip-unq.atlassian.net/browse/UNQ-27) | Implementar perfil | Por Hacer |
