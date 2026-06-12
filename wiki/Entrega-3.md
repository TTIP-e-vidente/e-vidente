# Entrega 3 — E-VIDENTE

> Histórico Entrega 3. Estado hoy: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md).

## Resumen ejecutivo

En esta iteración abrimos la persistencia remota sin sacar el juego del modo offline. Se levantó un backend Node con PostgreSQL en Docker, se integraron registro y login en el flujo real del juego, y se implementó la sincronización de progreso entre el save local y la cuenta. En paralelo avanzamos el nodo único de partida, las enseñanzas por JSON, smoke test en CI y tests de interfaz para Preguntas.

El criterio de diseño fue **local primero, sync después**: la partida no espera al servidor; si hay sesión, el resumen se sube en segundo plano o queda en cola para reintentar.

## Qué se agregó o modificó

- **Backend y PostgreSQL** — Docker Compose, migraciones, MER de usuario/perfil/progreso/partidas/racha; endpoints de auth y progreso documentados en `BACKEND/README.md`.
- **Cuenta y sesión** — registro, login y modo offline en el flujo Intro → Selector; pantallas de auth integradas al juego.
- **Sync de progreso** — merge local/remoto al loguearse, guardado de partida remota al terminar, cola offline y reintento; documentado en [Sync-Godot-Postgres](Sync-Godot-Postgres).
- **Perfil** — edición local de datos de usuario, sync de perfil y avatar; overlay de perfil en el HUD del mapa.
- **Nodo único de partida** — refactor hacia un nodo reutilizable que orquesta modalidades desde JSON del mapa (UNQ-170).
- **Enseñanzas JSON** — diseño de feedback y carga parametrizada desde archivos (UNQ-167, UNQ-168 en curso).
- **CI y smoke test** — workflow de smoke en PR (Intro → login/offline → selector → mapa → partida).
- **Tests UX Preguntas** — suite GdUnit4 sobre interfaz visible de la modalidad (UNQ-172 en curso).
- **Polish comidas** — borde blanco en sprites de alimentos para mejorar lectura en pantalla (UNQ-166).

## Desafíos técnicos

- Sincronizar progreso sin duplicar partidas ni perder avance offline (merge, `clientRunId`, cola local).
- Mantener Godot desacoplado de SQL: capa HTTP (`AuthApi`, `SyncApi`) y contrato REST estable.
- Unificar nodos del mapa sin romper el JSON y la demo de Celiaquía ya existente.
- Alinear fechas de racha entre servidor UTC y calendario local del jugador.

## Trazabilidad commit → ticket

| Commit | Descripción | Ticket(s) |
|---|---|---|
| `c3e9d0a` | Setup Docker PostgreSQL (#32) | UNQ-85 |
| `65bf2f1` | Encaminando Entrega 3 (#31) | Infra / mapa |
| `4def73a` | Login actualizado | UNQ-91 |
| `eb35afa` / `51eae03` | Sync local ↔ online | UNQ-160 |
| `28e1d0b` | AuthApi, SyncApi e importador | US-02, US-03 |
| `3f458a0` | MapApi, nomenclatura ES | US-05 |
| `80690ab` | Smoke test actualizado | CI |
| `b8e80e8` | Pool HTTP, cola local y background sync | US-03 |
| `e1521d8` | Endpoint perfil en backend | US-04 |
| `2e5a9e9` | Carga y descarga de avatar | US-04 |
| `daaa8bc` / `82a38cd` | Sync y badge de racha con fecha local | US-03 |
| `daf9a9a` | Estética Profile overlay | US-04 |
| `4616d6d` | Assets comidas | UNQ-166 |

## Alcance de Entrega 3

| Bloque | Resultado | Estado |
|---|---|---|
| Infra PostgreSQL | Docker, migraciones, MER dual | En revisión |
| Cuenta y sesión | Registro, login, offline | Listo (US-02) |
| Sync de progreso | Merge, cola, importador | En revisión |
| CI y smoke | Workflow en PR | Listo |
| Nodo único de partida | Refactor mapa / JSON | En revisión |
| Enseñanzas JSON | Feedback + carga parametrizada | En curso |
| Tests UX Preguntas | Suite GdUnit4 interfaz | En curso |
| Perfil dedicado | Diseño + overlay; escena completa | En curso |
| Polish comidas | Borde en sprites | Listo (US-08) |

### Fuera de alcance

Leaderboard, refresh token, admin, mails reales de recuperación, validación JSON en CI y deploy productivo del backend.

## Documentación

- [User Stories](Entrega-3-User-Stories)
- [Arquitectura](Entrega-3-Arquitectura)
- [Decisiones](Entrega-3-Decisiones)
- [Evidencia](Entrega-3-Evidencia)
- [Presentación](Entrega-3-Presentacion) — vista HTML del sprint (opcional)
- [Bitácora E3](Bitacora-Entrega-3)
