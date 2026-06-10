# Evidencia — Entrega 3

> Acá está **todo lo que podés mostrar** si te piden prueba: tickets de Jira, archivos en el repo y cómo probar cada bloque.  
> Sync con Jira: **10 jun 2026** · [proyecto UNQ](https://tip-unq.atlassian.net/jira/software/projects/UNQ/boards).

Para la defensa: abrí [Presentación](Entrega-3-Presentacion) (link «Pantalla completa») y tené [Cierre](Entrega-3-Cierre) como guión.

---

## Panorama del sprint

El sprint tiene **17 tickets** agrupados en **8 historias**. A hoy: **8 terminados**, **6 en revisión**, **3 en progreso**. Todo cuelga de la epic [UNQ-8](https://tip-unq.atlassian.net/browse/UNQ-8).

---

## Evidencia por user story

Cada fila resume **qué mostrar** si te preguntan por esa historia. Los criterios completos están en [User Stories](Entrega-3-User-Stories).

| US | Descripción | Tickets | Estado agregado |
|---|---|---|---|
| [US-01](Entrega-3-User-Stories#us-01--contar-con-infraestructura-de-persistencia-en-postgresql) | Infra PostgreSQL | UNQ-85, 87, 162, 161 | En revisión (161 ✅) |
| [US-02](Entrega-3-User-Stories#us-02--crear-cuenta-e-iniciar-sesión-en-el-juego) | Registro y login | UNQ-65, 171, 90, 91 | **Lista — 4/4 terminados** |
| [US-03](Entrega-3-User-Stories#us-03--sincronizar-progreso-local-con-la-cuenta-en-postgresql) | Sync de progreso | UNQ-160, 163 | En revisión |
| [US-04](Entrega-3-User-Stories#us-04--consultar-el-perfil-en-una-pantalla-dedicada) | Perfil dedicado | UNQ-107, 27 | En curso (107 ✅, 27 en progreso) |
| [US-05](Entrega-3-User-Stories#us-05--unificar-partidas-del-mapa-en-un-nodo-reutilizable) | Nodo único partida | UNQ-170 | En revisión |
| [US-06](Entrega-3-User-Stories#us-06--cargar-enseñanzas-y-su-feedback-desde-json) | Enseñanzas JSON | UNQ-167, 168 | En curso (167 ✅) |
| [US-07](Entrega-3-User-Stories#us-07--validar-la-uxui-de-la-modalidad-preguntas-con-tests-automatizados) | Test UX Preguntas | UNQ-172 | En progreso |
| [US-08](Entrega-3-User-Stories#us-08--mejorar-la-lectura-visual-de-los-alimentos-en-pantalla) | Borde comidas | UNQ-166 | **Terminada** |

---

## Tickets Jira del sprint

Esta tabla sale directo de Jira (10 jun 2026). La columna **US** es nuestra agrupación en la wiki — no reemplaza el workflow del tablero.

| Clave | Resumen | US | Estado Jira |
|---|---|---|---|
| [UNQ-85](https://tip-unq.atlassian.net/browse/UNQ-85) | Configurar PostgreSQL local con Docker | US-01 | Revisión |
| [UNQ-87](https://tip-unq.atlassian.net/browse/UNQ-87) | Validar conexión inicial con PostgreSQL | US-01 | Revisión |
| [UNQ-162](https://tip-unq.atlassian.net/browse/UNQ-162) | Modelar entidades principales del jugador | US-01 | Revisión |
| [UNQ-161](https://tip-unq.atlassian.net/browse/UNQ-161) | Identificar datos locales críticos a migrar | US-01 | **Terminado** |
| [UNQ-65](https://tip-unq.atlassian.net/browse/UNQ-65) | Diseñar registro de usuario | US-02 | **Terminado** |
| [UNQ-171](https://tip-unq.atlassian.net/browse/UNQ-171) | Diseñar pantalla de login | US-02 | **Terminado** |
| [UNQ-90](https://tip-unq.atlassian.net/browse/UNQ-90) | Implementar registro de usuario | US-02 | **Terminado** |
| [UNQ-91](https://tip-unq.atlassian.net/browse/UNQ-91) | Implementar login de usuario | US-02 | **Terminado** |
| [UNQ-160](https://tip-unq.atlassian.net/browse/UNQ-160) | Migrar y sincronizar progreso local | US-03 | Revisión |
| [UNQ-163](https://tip-unq.atlassian.net/browse/UNQ-163) | Guardar resumen de partida | US-03 | Revisión |
| [UNQ-107](https://tip-unq.atlassian.net/browse/UNQ-107) | Diseñar pantalla de perfil | US-04 | **Terminado** |
| [UNQ-27](https://tip-unq.atlassian.net/browse/UNQ-27) | Implementar escena de perfil | US-04 | En progreso |
| [UNQ-170](https://tip-unq.atlassian.net/browse/UNQ-170) | Nodo único multi-modalidad | US-05 | Revisión |
| [UNQ-167](https://tip-unq.atlassian.net/browse/UNQ-167) | Diseñar feedback enseñanzas | US-06 | **Terminado** |
| [UNQ-168](https://tip-unq.atlassian.net/browse/UNQ-168) | Feedback enseñanzas JSON | US-06 | En progreso |
| [UNQ-172](https://tip-unq.atlassian.net/browse/UNQ-172) | Test UX/UI Preguntas | US-07 | En progreso |
| [UNQ-166](https://tip-unq.atlassian.net/browse/UNQ-166) | Borde blanco en comidas | US-08 | **Terminado** |

**JQL para refrescar:** `key in (UNQ-85, UNQ-87, UNQ-162, UNQ-161, UNQ-65, UNQ-171, UNQ-90, UNQ-91, UNQ-160, UNQ-163, UNQ-107, UNQ-27, UNQ-170, UNQ-167, UNQ-168, UNQ-172, UNQ-166) ORDER BY key ASC`

---

## Evidencia técnica por bloque

Para cada historia: **qué mirar en el repo** y **cómo demostrarlo** en cinco minutos.

### US-01 — Infraestructura PostgreSQL

| Qué | Dónde | Cómo probar |
|---|---|---|
| Docker Compose | `BACKEND/docker-compose.yml` | `docker compose up -d` en `BACKEND/` |
| Migraciones | `BACKEND/migrations/` (002–016) | Script de migrate documentado en `BACKEND/README.md` |
| Modelo / MER | [Mer-Persistencia-E3](Mer-Persistencia-E3), [MER](MER) | Revisar diagrama dual local + Postgres |
| Relevamiento datos locales | UNQ-161 cerrado; ver bitácora sync | Comparar campos `SaveManager` vs tablas backend |

### US-02 — Cuenta y sesión

| Qué | Dónde | Cómo probar |
|---|---|---|
| API auth | `BACKEND/src/modules/auth/` | POST register/login con curl o Postman |
| Cliente Godot | `juego/API/backend/`, `juego/interface/auth.gd` | Intro → Registro → Login → Selector |
| Modo offline | flujo Intro sin backend | “Continuar offline” llega al mapa |
| Pantallas diseño | UNQ-65, UNQ-171 terminados | Recorrido visual login/registro |

### US-03 — Sincronización

| Qué | Dónde | Cómo probar |
|---|---|---|
| Servicio sync | `ProgressSyncService`, `SyncApi.gd` | Jugar offline → login → verificar merge |
| Importador | `ImportadorProgresoOnline.gd` | Save local previo + cuenta nueva |
| Cola offline | lógica en `SaveManager.gd` | Apagar backend, terminar partida, reencender |
| Doc flujo | [Sync-Godot-Postgres.md](Sync-Godot-Postgres) | Seguir diagrama login + post-partida |

### US-04 — Perfil

| Qué | Dónde | Cómo probar |
|---|---|---|
| Diseño | UNQ-107 terminado | Mock / Figma referenciado en ticket |
| Implementación | UNQ-27 en progreso | Navegar a escena perfil cuando esté mergeada |
| Datos | perfil local + remoto | Métricas, racha, continuar al mapa |

### US-05 — Nodo único de partida

| Qué | Dónde | Cómo probar |
|---|---|---|
| Refactor mapa | `MapBoard.gd`, nodos partida | Partidas con ≥2 modalidades en celiaquía |
| JSON contenido | `juego/contenido/`, mapa JSON | Cambiar modalidades sin nuevo tipo de nodo |

### US-06 — Enseñanzas JSON

| Qué | Dónde | Cómo probar |
|---|---|---|
| Diseño feedback | UNQ-167 terminado | Revisar ticket / assets |
| Carga JSON | scripts modalidad enseñanzas | Agregar entrada en JSON sin tocar GDScript |
| UNQ-168 | en progreso | Partida con enseñanza parametrizada |

### US-07 — Tests UX Preguntas

| Qué | Dónde | Cómo probar |
|---|---|---|
| Suite | `juego/tests/preguntas/test_modalidad_preguntas_ux_ui.gd` | GdUnit4 desde Godot o CI |
| Alcance | interfaz visible, no balance pedagógico | Carga → opciones → feedback → continuar |

### US-08 — Comidas

| Qué | Dónde | Cómo probar |
|---|---|---|
| Sprites | assets comidas UNQ-166 | Modalidades arrastre / catálogo |
| Estado | Terminado en Jira | Demo visual en defensa |

### Transversal — CI

| Qué | Dónde | Cómo probar |
|---|---|---|
| Smoke test | `juego/tests/vertical_slice_smoke_test.gd` | Workflow Gameplay Smoke en PR |
| CI monorepo | `.github/workflows/`, `scripts/ci/` | Technical Health en PR |

---

## Evidencia de CI

Workflows documentados en [CI.md](CI.md):

| Workflow | Qué valida |
|---|---|
| **Docs / Tracking** | Bitácora y trazabilidad en PR |
| **Technical Health** | Estructura mínima monorepo |
| **Gameplay Smoke** | Intro → Login → offline → Selector → mapa → partida |

---

## Evidencia de commits

Muestra representativa (no exhaustiva). Trazabilidad completa en git log y [Bitacora-Entrega-3](Bitacora-Entrega-3).

| Commit | Descripción | Ticket(s) |
|---|---|---|
| `c3e9d0a` | Setup Docker PostgreSQL (#32) | UNQ-85 |
| `65bf2f1` | Encaminando Entrega 3 (#31) | Infra / mapa |
| `28e1d0b` | AuthApi, SyncApi e importador | US-02, US-03 |
| `eb35afa` / `51eae03` | Sync local ↔ online | UNQ-160 |
| `4def73a` | Login actualizado | UNQ-91 |
| `3f458a0` | MapApi, nomenclatura ES | US-05 |
| `80690ab` | Smoke test actualizado | CI |

---

## Cómo refrescar esta página

1. Corré el JQL de [Tickets](#tickets-jira-del-sprint) en Jira.
2. Actualizá estados y recalculá el resumen por US.
3. Si cambió algo grande, actualizá también [Presentación](Entrega-3-Presentacion).

Wiki publicada: `https://github.com/TTIP-e-vidente/e-vidente/wiki/Entrega-3-Evidencia`
