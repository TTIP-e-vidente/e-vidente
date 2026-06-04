# Bitácora — POC

[← Índice](Bitacora) · **Abr 2026** · Commits ~`3588816` (3-abr) → `2017063` (17-abr), antes de integración de mapa (#10).

Prueba de concepto: juego local en Godot con save, arrastre mejorado, selector, primeras pistas de tracks (keto/cuestionario), racha y estabilización. Sin mapa de progreso completo ni entrega TTIP formal.

Tickets UNQ de esta etapa suelen estar absorbidos en [Entrega-1-Evidencia](Entrega-1-Evidencia) al cerrar E1.

Más nuevo arriba.

---

### `2026-04-17` — Refactor niveles y save (#8)
<kbd>Save</kbd> <kbd>Refactor</kbd>

**Qué problema resolvió**
- Deuda acumulada tras sumar racha y modalidades; save y niveles difíciles de mantener.

**Qué se implementó**
- Limpieza de gestión de niveles y sistema de guardado.
- PR #8 `Refactor and clean up level management and save system`.

**Evidencia**
- `2017063`, `d29e154`
- `juego/interface/SaveManager.gd`, `juego/niveles/manager_level.gd`

---

### `2026-04-17` — Racha del jugador (#7)
<kbd>Gameplay</kbd> <kbd>Racha</kbd>

**Qué se implementó**
- Lógica de racha diaria ligada al perfil/sesión local.
- PR #7 `Feature/racha player`.

**Impacto**
- Base para US-03 (indicador de racha) en Entrega 1.

**Evidencia**
- `410d31d`
- Relacionado: `GameStreakTracker`, escenas de racha (evolución en abr 26)

---

### `2026-04-16` — Limpieza de código (#6)
<kbd>Calidad</kbd>

**Qué se hizo**
- Refactor general para legibilidad antes de features grandes.
- PR #6 `Feature/code clean`.

**Evidencia**
- `e5f9e52`

---

### `2026-04-11` — Fixes de gameplay (#5)
<kbd>Bug</kbd> <kbd>Gameplay</kbd>

**Qué se hizo**
- Correcciones de issues de jugabilidad detectados en pruebas internas.
- PR #5 `Fix/issues gameplay`.

**Evidencia**
- `f8ecc68`

---

### `2026-04-10` — Cuestionario y track cetogénico (#3, #4)
<kbd>Modalidad</kbd> <kbd>Contenido</kbd>

**Qué se implementó**
- Flujo de **preguntas / cuestionario** jugable (PR #4).
- Avance en track **cetogénica**: enseñanzas, pools de items (`c867f36`, `e7cbacd`).
- Selector: botón atrás (`e16bd58`).
- PR #3 `Feat/cetogenica`.

**Impacto**
- Primeras modalidades además del arrastre (plato).
- Validación de que el contenido podía parametrizarse por track.

**Evidencia**
- `4e1f0ae`, `1883c28`, `c867f36`
- `juego/preguntas/`, libros keto en `juego/interface/`

---

### `2026-04-07` — Merge save local y CI en `dev` (#1, #2)
<kbd>Save</kbd> <kbd>CI</kbd>

**Qué se implementó**
- **Persistencia local**: perfil, progreso, auth de perfil local, Archivero, reset de progreso.
- Tests con singletons (`SaveManager`, `Global`).
- CI: Godot 4.6.2 headless, perfiles de validación, rama `dev`.
- PR #1 `feat/save-local` → merge `7eb41e0`; integración dev `ac65e15`.

**Qué problema resolvió**
- Demo que sobrevive al cerrar el juego sin backend.

**Impacto**
- Pilar de toda Entrega 1 (US-03, archivero, perfil).

**Tickets relacionados (E1)** — UNQ-89, 97, 115 (progreso) vía save local.

**Evidencia**
- `3588816` … `7eb41e0`, `ac65e15`
- `juego/interface/SaveManager.gd`, `save_local/`, `auth.tscn`
- PR #1, #2

---

### `2026-04-05` — Arrastre, ítems y validación Godot
<kbd>Gameplay</kbd> <kbd>CI</kbd>

**Qué se implementó**
- Mejoras en `ItemLevel` (drag-and-drop).
- Catálogo de contenido y validación inicial.
- Scripts de import headless (`--editor --quit`).
- Hooks locales → luego movidos a GitHub Actions.

**Evidencia**
- `69e201d`, `a4249cd`, `7c98c29`, `75e5356`
- `juego/items/ItemLevel.gd`

---

### `2026-04-03` — Inicio persistencia local (POC jugable)
<kbd>Save</kbd> <kbd>POC</kbd>

**Qué se implementó**
- Primer sistema de **persistencia local** con autenticación de perfil y tracking de progreso (`3588816`).
- Refactor de paths y configuración del proyecto.

**Impacto**
- El juego deja de ser solo sesión en memoria: nace la demo defendible.

**Evidencia**
- `3588816`, `579770c`, `ca4d342`
