# Bitácora — Entrega 1

[← Índice](Bitacora) · Resumen TTIP: [Entrega-1](Entrega-1) · [Evidencia](Entrega-1-Evidencia) · [User Stories](Entrega-1-User-Stories)

**Abr 18 – May 16, 2026.** Demo local: mapa, partida por nodo, tres modalidades, JSON, celiaquía, cierre de lección. Reconstruido desde git + tickets UNQ de evidencia.

Más nuevo arriba.

---

### `2026-05-16` — Cierre técnico Entrega 1 (#23) y wiki TTIP
<kbd>Entrega</kbd> <kbd>Docs</kbd> <kbd>CI</kbd>

**Qué se implementó**
- Merge principal `merge/vinculacion-partidaxnodo` → PR **#23**.
- Wiki: Entrega-1 (arquitectura, user stories, decisiones, evidencia), MER (`mer.html`), Entregas.md, Como-Empezar, Arquitectura-General.
- Ajustes CI: Godot install directo, `Inicio.md`, strip co-author en commits.
- Refactor de nombres de variables en español (`bc6c09b`).

**Impacto**
- Entrega 1 defendible en TTIP con trazabilidad ticket ↔ historia.

**Evidencia**
- `57ac256`, `6a04de3`, `4962d17`, `51f84a1`, `d0f4ee1`
- `wiki/Entrega-1*.md`, PR #23

---

### `2026-05-14` — Documentación formal Entrega 1 y MER
<kbd>Docs</kbd> <kbd>Entrega</kbd>

**Qué se hizo**
- Paquete de docs: arquitectura, evidencia, user stories, decisiones, próximos pasos, modelo relacional.
- Diagrama MER y refinado del flujo confirmado del jugador.
- Limpieza de docs obsoletos (Pages, domain model viejo).

**Tickets / historias** — ver tablas en [Entrega-1-Evidencia](Entrega-1-Evidencia) (UNQ-84…UNQ-106).

**Evidencia**
- `29d5325`, `45773a2`, `2314c62`, `7894d70`
- `wiki/Entrega-1*.md`, `wiki/mer.html`

---

### `2026-05-13` — Catálogo celiaquía, mapa y bug del plato
<kbd>Bug</kbd> <kbd>Gameplay</kbd> <kbd>Contenido</kbd>

**Qué se implementó**
- `items_celiaquia` y ajustes de jugabilidad en mapa celiaquía.
- Sonido al finalizar partida.
- **Bug del plato**: feedback consistente al soltar incorrecto (`1dd36b6`).

**Tickets relacionados** — UNQ-127 (Plato error), UNQ-104 (estabilidad).

**Impacto**
- Demo de arrastre estable para exposición.

**Evidencia**
- `7680b14`, `a3d8f04`, `daa8365`, `1dd36b6`
- `juego/items/ItemLevel.gd`, `juego/niveles/manager_level.gd`
- `juego/contenido/catalogos/items_celiaquia.json`

---

### `2026-05-10` — Lección terminada y barra de progreso (#21, #22)
<kbd>UI</kbd> <kbd>Cierre</kbd> <kbd>Progreso</kbd>

**Qué se implementó**
- Pantalla / flujo de **lección completa** (PR #21).
- **Barra de progreso** durante partida (PR #22).
- Acumulación de estadísticas por minijuego (`657b80c`).

**Tickets** — UNQ-94, UNQ-118, UNQ-116 (cierre); UNQ-89, UNQ-121 (barra).

**Impacto**
- US-04 y US-03: cierre explícito y progreso visible.

**Evidencia**
- `ffe8a77`, `30eb2a1`, `657b80c`
- `juego/mapas/finalizacion_partida`, `progress_bar.gd`

---

### `2026-05-11` — Resumen semanal en perfil
<kbd>UI</kbd> <kbd>Progreso</kbd>

**Qué se implementó**
- `WeeklyLearningSummary` en overlay de perfil.

**Tickets** — UNQ-115 (resumen semanal).

**Evidencia**
- `35ef055`
- `juego/interface/components/WeeklyLearningSummary.gd`

---

### `2026-05-08` — Merge vinculación + partida por nodo (rama larga)
<kbd>Gameplay</kbd> <kbd>Modalidad</kbd> <kbd>Contenido</kbd>

**Qué se implementó**
- Quiz y **match/vincular** para conciencia sobre gluten.
- Opciones de quiz 2/3/4, shuffle, más nodos drag en JSON.
- UI y lógica de `ConceptoItem` / `VincularConceptos`.
- Historial de sesión para no repetir activities random (`e2e8abc`, `89749d6`).
- Sistema de **meals** en catálogo (`311dfad`).

**Tickets** — UNQ-60, 123, 128 (vincular); UNQ-110 (preguntas); UNQ-106 (contenido).

**Evidencia**
- `2d3b290` … `1bfc7c6`, rama `merge/vinculacion-partidaxnodo`
- `juego/vincular/`, `juego/contenido/mapa/preguntas.json`, `vinculaciones.json`

---

### `2026-05-06` — Vincular conceptos + validación de contenido
<kbd>Modalidad</kbd> <kbd>Sistema</kbd>

**Qué se implementó**
- Esqueleto y escena de **vinculación** mergeada con partida por nodo (`4afa00d`, `b2e96f1`).
- Sistemas de gestión y validación de contenido (`4b3aaac`, `0d8c677`).
- Refactor `ContinuarJuego`, contexto de juego unificado.

**Evidencia**
- `4afa00d`, `bdc1682`, `4b3aaac`, `eb1da20`
- `juego/vincular/vincular_conceptos.gd`, `sistemas/contenido/`

---

### `2026-05-05` — Partida por nodo y multi-game en JSON
<kbd>Mapa</kbd> <kbd>Contenido</kbd>

**Qué se implementó**
- Soporte de **varios games por nodo** vía JSON (`d2b60b8`).
- Capa de enseñanza en Level, parametrización de selector y animaciones.
- Estados de racha en partida (`281248c`).

**Tickets** — base para US-01 (recorrido por nodo).

**Evidencia**
- `d2b60b8`, `b0b0e45`, `d887261`, `ff5d67d`
- `juego/mapas/logica/ArmadorDePartida.gd`, `ContinuidadDePartidaDeNodo.gd`

---

### `2026-05-04` — Indicador de progreso y continuidad entre games
<kbd>UI</kbd> <kbd>Mapa</kbd>

**Qué se implementó**
- Indicador de progreso en partida y continuidad entre minijuegos del mismo nodo.
- Dificultad en arrastre; preguntas celiaquía; fix bug del mapa (`c4712eb`).

**Evidencia**
- `fb74c08`, `d7a6592`, `4d49413`, `04dead9`
- Rama `feat/partida-por-nodo`

---

### `2026-05-02` — Mapa celiaquía y contenido del capítulo
<kbd>Mapa</kbd> <kbd>Contenido</kbd>

**Qué se implementó**
- `celiaquia_mapa.json` y nodos del capítulo educativo (`f176489`).
- Mejoras en `ContinueCountdown` y flujo post-partida.

**Tickets** — UNQ-124 (lineamiento mapa), UNQ-84 (visual al completar).

**Evidencia**
- `f176489`, `b237089`, `48f7a02`
- `juego/contenido/mapa/celiaquia_mapa.json`

---

### `2026-05-01` — Núcleo del mapa (scripts core)
<kbd>Arquitectura</kbd> <kbd>Mapa</kbd>

**Qué se implementó**
- Reorganización: `MapNodeData`, loaders, compatibilidad legacy.
- Fixes de gameplay tras refactor.

**Evidencia**
- `a74958a`, `459c6a6`, `602d43d`, `8e1182d`
- `juego/mapas/core/`, `juego/mapas/logica/`

---

### `2026-04-30` — Continuación en mapa y countdown
<kbd>Mapa</kbd> <kbd>UX</kbd>

**Qué se implementó**
- Flujo para pasar al siguiente game/nodo desde el mapa.
- Componente `ContinueCountdown`.

**Evidencia**
- `d5db84e`, `a55ecd6`
- `juego/interface/components/ContinuarJuego/`

---

### `2026-04-29` — MapScene y contenido por JSON (#18)
<kbd>Arquitectura</kbd> <kbd>Contenido</kbd>

**Qué problema resolvió**
- Niveles acoplados a escenas; difícil escalar partidas.

**Qué se implementó**
- **MapScene** para navegación del capítulo.
- **NodeContentLoader** (evolución del cargador de nodos) y contenido JSON por nodo.
- PR **#18** `Feature/node content json`.

**Impacto**
- Pilar de “contenido desacoplado” en Entrega 1.

**Evidencia**
- `13744fa`, `eb2e8c3`
- `juego/mapas/MapScene.gd`, `juego/sistemas/contenido/NodeContentLoader.gd`

---

### `2026-04-27` — Preguntas y arrastre desde JSON
<kbd>Contenido</kbd> <kbd>Modalidad</kbd>

**Qué se implementó**
- Refactor de preguntas para cargar desde JSON (`3bef8a6`).
- Drag-drop nodes y validación de JSON de arrastre.
- Música en loop (#17, `8ad7522`).

**Tickets** — UNQ-126 (transparencia pregunta); audio largo sesión.

**Evidencia**
- `3bef8a6`, `cc6e25f`, `821a219`, `8ad7522`
- `juego/preguntas/QuestionJsonLoader.gd`

---

### `2026-04-26` — Racha en escena y guías de UI
<kbd>Racha</kbd> <kbd>Docs</kbd>

**Qué se implementó**
- Integración de racha en escenas de juego (PRs #12–#16).
- Guidelines scene-first y theming (`94ab449`).

**Tickets** — UNQ-83 (indicador racha al ingresar).

**Evidencia**
- `39c836b` … `221340b`, `94ab449`

---

### `2026-04-20` — Bloqueo al fin de nivel y navegación (#11)
<kbd>UX</kbd> <kbd>Gameplay</kbd>

**Qué se implementó**
- Organización de componentes al terminar nivel; ajustes botón atrás.
- PR #11 `Feature/lock on level end organize components`.

**Evidencia**
- `ac0e132`, `e1767d2`, `ab29c43`

---

### `2026-04-18` — Integración del mapa en `dev` (#10)
<kbd>Mapa</kbd> <kbd>Hito</kbd>

**Qué problema resolvió**
- Juego lineal sin mapa de progreso visual.

**Qué se implementó**
- **Integración del mapa** como eje del recorrido (PR **#10**).
- Inicio de la línea de trabajo que cierra en celiaquía + vinculación (mayo).

**Tickets** — UNQ-84, UNQ-93, UNQ-92, UNQ-100 (flujo mapa).

**Impacto**
- US-01: elegir nodo, completar, ver progreso, rejugar.

**Evidencia**
- `3130c95` — PR #10
- `juego/mapas/`, `juego/interface/libro*.gd`

---

## Nota sobre tickets Jira

Los UNQ listados salen de [Entrega-1-Evidencia](Entrega-1-Evidencia) y [Entrega-1](Entrega-1). Para descripción completa del ticket en Jira, buscar por clave `UNQ-xxx`. Si exportás CSV de Jira, se puede pegar una columna “commit / fecha” en cada entrada.
