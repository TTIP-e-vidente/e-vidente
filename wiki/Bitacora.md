# Bitácora

> Cambios importantes que anotamos para no perder de vista la evolución del proyecto.
> Esta página no reemplaza documentos de entrega — su rol es dejar trazabilidad clara de **qué se hizo**, **por qué**, **qué problema resolvió**, **qué impacto tuvo** para el jugador y **qué evidencia técnica** lo respalda.

---

## Navegación por etapas

| Etapa | Documento |
|---|---|
| Pre-POC | [Pre-POC.md](Pre-POC.md) |
| POC | [01-POC.md](01-POC.md) |
| Entrega 1 | [02-Entrega-1.md](02-Entrega-1.md) |
| Entrega 2 | [03-Entrega-2.md](03-Entrega-2.md) |
| Próximas entregas | [04-Entrega-3.md](04-Entrega-3.md) |
| Entrega final | [05-Entrega-Final.md](05-Entrega-Final.md) |

> ⚠️ **Falta confirmar** si ya están creados todos los documentos de etapa.

---

## Lo que pasó recientemente

Acá están los cambios más nuevos y relevantes para demo, defensa TTIP y continuidad técnica.

---

### `2026-05-23` — Barra de progreso completa antes de finalizar la última partida
<kbd>🖼️ UI</kbd> <kbd>✨ UX</kbd> <kbd>📊 Progreso</kbd>

Se ajustó el cálculo de la barra para que durante la última partida muestre el avance previo y recién llegue visualmente al 100% al cerrar esa partida.

**Qué problema resolvió**
- En la última partida, la barra podía mostrarse como completa antes de que esa partida estuviera efectivamente terminada.
- El progreso debía representar las partidas ya completadas (`total - 1`) mientras el último juego seguía en curso.

**Qué se implementó**
- Método explícito `completar_progreso()` en la barra compartida.
- Llamada de cierre en modalidades que limpian estado al finalizar la partida por nodo.
- Actualización visual de `Progress_Bar.tscn` para sostener el indicador inferior.

**Impacto para el jugador**
- El avance visual ya no se adelanta al estado real del juego.
- El 100% queda asociado al cierre efectivo del nodo y al paso a resultados.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/interface/progress_bar.gd`
- `project/interface/Progress_Bar.tscn`
- `project/niveles/nivel_1/Level.gd`
- `project/preguntas/pregunta.gd`
- `project/completar/completar_palabra.tscn`
- Commit: `b98b755` — *Feature/implementacion estrellas (#27)*
- Commit: `87c9ef7` — *Actualizada la progress bar*

</details>

---

### `2026-05-22` — Transición suave de partida a resultados
<kbd>✨ UX</kbd> <kbd>🏁 Cierre</kbd> <kbd>🎞️ Transición</kbd>

Se consolidó el paso desde la última actividad del nodo hacia la pantalla de resultados usando el flujo de transición, evitando saltos secos entre juego, cierre y mapa.

**Qué problema resolvió**
- El cierre de partida podía sentirse abrupto cuando terminaba el último minijuego y se cambiaba de escena.

**Qué se implementó**
- Uso de `TransicionEscenas` desde `GameSceneRouter` y desde la pantalla de finalización.
- Apertura de `Finalización-Partida.tscn` cuando `Global` conserva resultados pendientes.
- Lectura y limpieza de datos de finalización antes de volver al mapa.

**Impacto para el jugador**
- La salida del juego se siente más ordenada.
- Los resultados aparecen como parte del flujo de cierre, no como un corte aislado.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/interface/transiciones/transicion_escenas.gd`
- `project/interface/transiciones/transicion_escenas.tscn`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/MapScene.gd`
- `project/mapas/Finalización-Partida.tscn`
- `project/mapas/finalización_partida.gd`
- `project/niveles/global.gd`
- Commit: `76991a3` — *feat: sistema de transiciones de escenas con GameSceneRouter (#26)*
- Commit: `cd05ab4` — *Transicion correcta*

</details>

---

### `2026-05-21` — Estrellas de precisión en el mapa
<kbd>🖼️ UI</kbd> <kbd>📊 Progreso</kbd> <kbd>💾 Persistencia</kbd>

Se agregó una estrella de progreso para que los nodos completados reflejen la mejor precisión obtenida y no solo el estado binario terminado/no terminado.

**Qué problema resolvió**
- El mapa mostraba avance, pero no comunicaba la calidad del desempeño en cada nodo.

**Qué se implementó**
- Componente `StarProgress` con relleno proporcional de 0 a 1.
- Guardado de `best_accuracy` y `last_accuracy` por nodo en `SaveManager`.
- Lectura del progreso guardado desde `MapScene` y aplicación visual en `LevelNode`.

**Impacto para el jugador**
- El mapa devuelve feedback más claro sobre precisión.
- El jugador puede reconocer dónde completó bien y dónde podría mejorar.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/mapas/components/StarProgress.gd`
- `project/mapas/components/StarProgress.tscn`
- `project/mapas/LevelNode.gd`
- `project/mapas/MapScene.gd`
- `project/interface/SaveManager.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- Commit: `c1e61d1` — *feat: Implementando Estrella de progreso*
- Commit: `b98b755` — *Feature/implementacion estrellas (#27)*

</details>

---

### `2026-05-20` — Completar con opciones de palabras
<kbd>🎮 Gameplay</kbd> <kbd>🔧 Modalidad</kbd> <kbd>📝 Contenido</kbd>

Se incorporó una modalidad donde el jugador completa frases eligiendo palabras disponibles, integrada al mismo plan de partida por nodo que el resto de minijuegos.

**Qué problema resolvió**
- Los nodos necesitaban más variedad de interacción sin duplicar rutas ni hardcodear desafíos en escenas.

**Qué se implementó**
- Escena y script `completar_palabra` con validación de respuestas, feedback de error y cierre único del minijuego.
- Carga de desafíos desde JSON por dificultad mediante `CargadorCompletar`.
- Routing por `ModalidadRouter` y `GameSceneRouter`, más continuidad en `ContinuidadDePartidaDeNodo`.

**Impacto para el jugador**
- La experiencia suma una actividad de lectura/comprensión con reintento inmediato.
- El avance del nodo se mantiene consistente con quiz, arrastre y vinculación.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/completar/completar_palabra.gd`
- `project/completar/completar_palabra.tscn`
- `project/completar/CargadorCompletar.gd`
- `project/contenido/mapa/completar_palabra.json`
- `project/contenido/mapa/celiaquia_mapa.json`
- `project/sistemas/ModalidadRouter.gd`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/tests/vertical_slice_smoke_test.gd`
- Commit: `7fe7dcb` — *feat: implement CompletarPalabra mini-game mode and scene structure*
- Commit: `73174e4` — *Feature/opciones json (#25)*

</details>

> ⚠️ **Riesgo detectado:** `project/tests/vertical_slice_smoke_test.gd` todavía conserva algunas referencias textuales a rutas antiguas `res://opciones_palabras/...`, aunque la modalidad actual vive en `res://completar/...`.

---

### `2026-05-16` — Integración de vinculacion-partidaxnodo en dev y apertura de PR a main
<kbd>🔀 Integración</kbd> <kbd>🧹 Limpieza</kbd> <kbd>🚀 PR</kbd>

Se integró la rama `merge/vinculacion-partidaxnodo` en `dev`, se preparó `dev` para la PR hacia `main` y se limpió el historial de co-authors de Copilot/Autopilot.

**Qué se hizo**
- Merge de `origin/merge/vinculacion-partidaxnodo` en `dev` priorizando cambios de la rama entrante (`-X theirs`). Archivos clave incorporados: `Finalización-Partida.tscn`, `NodoRuntime.gd`, `ArmadorDePartida.gd` y lógica completa de partida por nodo.
- Se resolvieron todos los conflictos estructurales (rename/delete) a favor de la versión nueva.
- Se sincronizó `dev` con `main` para que la PR quede limpia (merge de `main` en `dev` con `-X ours`).
- Se corrigió parse error en `ItemLevel.gd` (funciones `set_interaction_enabled` e `is_interaction_enabled` duplicadas) que rompía el smoke test.
- Se abrió PR #24 `dev → main`.

**Impacto**
- La PR a `main` refleja el estado completo de `dev` incluyendo la lógica de vinculación nodo-partida.
- El smoke test vuelve a pasar (`Validacion Godot completada correctamente`).
- El historial de `dev` queda limpio de atribuciones automáticas de Copilot.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/items/ItemLevel.gd` — eliminación de funciones duplicadas
- `.githooks/commit-msg` — hook preventivo co-author
- PR activa: [Dev #24](https://github.com/TTIP-e-vidente/e-vidente/pull/24)
- Commits de merge: `b585fd6`, `8419e05`

</details>

---

### `2026-05-13` — Corrección del comportamiento del plato
<kbd>🐛 Bug</kbd> <kbd>🎮 Gameplay</kbd>

Se corrigió un problema en la actividad de arrastre donde la interacción con el plato podía generar respuestas inconsistentes para ciertos intentos incorrectos.

**Qué problema resolvió**
- En la práctica, había casos donde el feedback no era suficientemente consistente cuando un ítem se soltaba en una condición inválida.

**Qué se ajustó**
- Se reforzó el flujo de intento incorrecto en el ítem arrastrable.
- Se dejó señal explícita para el caso incorrecto.
- Se mantuvo la recuperación visual para no cortar la interacción.

**Impacto para el jugador**
- El gameplay se siente más estable.
- Se reducen respuestas confusas durante la actividad.
- La demo queda más predecible para exposición.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/items/ItemLevel.gd`
- `project/niveles/manager_level.gd`
- Commit: `7738db4` — *Resuelvo bug del plato*

</details>

> ⚠️ **Falta confirmar:** ID o referencia formal del bug en ticket externo.

---

### `2026-05-10` — Barra de progreso durante la actividad
<kbd>🖼️ UI</kbd> <kbd>📊 Progreso</kbd>

Se incorporó y consolidó una barra de progreso para que el jugador entienda cuánto avanzó dentro de la secuencia del nodo.

**Qué problema resolvió**
- Antes, el avance podía sentirse opaco en actividades encadenadas.

**Qué se implementó**
- Indicador visual de avance en escenas de modalidad.
- Actualización del progreso con contexto `actual/total` del juego activo.
- Unificación del criterio visual para evitar duplicidad de indicadores.

**Impacto para el jugador**
- Ahora entiende cuánto le falta para terminar.
- La experiencia se siente más guiada.
- Se reduce incertidumbre entre un juego interno y el siguiente.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/interface/progress_bar.gd`
- `project/interface/Progress_Bar.tscn`
- `project/preguntas/pregunta.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/niveles/nivel_1/Level.gd`
- Commit: `e02c1d8` — *Feature/barra progreso*

</details>

---

### `2026-05-10` — Estado de lección terminada y finalización de nodo
<kbd>✨ UX</kbd> <kbd>🏁 Cierre</kbd>

Se agregó una instancia clara de finalización para comunicar cierre de lección/nodo y sostener una salida ordenada al mapa.

**Qué problema resolvió**
- El cierre podía sentirse abrupto cuando terminaba la actividad.

**Qué se implementó**
- Pantalla de finalización de partida con métricas.
- Registro de finalización en estado global para mostrarla en el momento correcto.
- Retorno controlado al mapa después del cierre.

**Impacto para el jugador**
- La actividad ya no termina de forma abrupta.
- Se refuerza la sensación de logro.
- El flujo de demo queda más defendible de punta a punta.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/mapas/Finalización-Partida.tscn`
- `project/mapas/finalización_partida.gd`
- `project/mapas/completo/finalizacion_de_nodo.gd`
- `project/mapas/MapScene.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/niveles/global.gd`
- Commit: `893b57a` — *Lección Completa*

</details>

---

### `Falta confirmar fecha` — Vinculación de conceptos como nueva modalidad
<kbd>🎮 Gameplay</kbd> <kbd>🔧 Modalidad</kbd>

Se incorporó `vinculacion_conceptos` dentro del flujo de partida por nodo, sin abrir un camino paralelo al resto de modalidades.

**Qué problema resolvió**
- El nodo tenía menos variedad de interacción y menor capacidad de trabajar relaciones conceptuales.

**Qué se implementó**
- Nuevo modo `vinculacion_conceptos` en routing y continuidad.
- Integración de escena y runtime dentro del mismo esquema post-juego.
- Cobertura en smoke del recorrido que incluye la modalidad.

**Impacto para el jugador**
- El contenido educativo gana variedad.
- Los nodos pueden mezclar más de una forma de actividad.
- La arquitectura muestra extensibilidad real, no teórica.

<details>
<summary>📁 Evidencia técnica</summary>

- `project/sistemas/ModalidadRouter.gd`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/vincular/VincularConceptos.tscn`
- `project/tests/vertical_slice_smoke_test.gd`
- `project/contenido/mapa/vinculaciones.json`

</details>

> ⚠️ **Falta confirmar:** Fecha única de corte para declarar la modalidad como cerrada en todos los tracks.

---

### `2026-05-05` — Partida por nodo con múltiples juegos internos
<kbd>🎮 Gameplay</kbd> <kbd>🏗️ Arquitectura</kbd>

Se consolidó el modelo donde un nodo puede ejecutar una secuencia de juegos internos, evitando hardcodeo de escenas y habilitando composición por datos.

**Qué problema resolvió**
- Un nodo rígido limita variaciones de gameplay y obliga a cambios de código para cada ajuste de contenido.

**Qué se implementó**
- Armado de `plan_de_partida` con `juegos` internos y continuidad.
- APIs globales para iniciar, consultar, avanzar y finalizar partida de nodo.
- Orquestación `mapa → apertura → juego → continuidad → cierre`.

**Impacto para el jugador y para producto**
- Un nodo puede combinar más de una actividad sin hardcodear escenas.
- Se escala contenido con menor costo de mantenimiento.
- El diseño pedagógico gana flexibilidad.

<details>
<summary>📁 Evidencia técnica</summary>

- `wiki/Partida-por-nodo.md`
- `project/mapas/logica/ArmadorDePartida.gd`
- `project/mapas/logica/AbridorDeNodoJugable.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/niveles/global.gd`
- `project/contenido/mapa/celiaquia_mapa.json`
- Commit: `30760ef` — *multi-game node support*

</details>

---

### `2026-05-03` — Contenido JSON desacoplado para nodos jugables
<kbd>📝 Contenido</kbd>

Se reforzó el desacople entre lógica del juego y contenido de actividades, priorizando nodos definidos por JSON.

**Qué problema resolvió**
- Con contenido embebido en escenas, cada cambio de actividad obligaba a tocar código o assets de gameplay.

**Qué se implementó**
- Contrato de carga/validación de contenido por nodo.
- Soporte de modos y normalización de payload para runtime.
- Mapa con nodos que contienen `games` y rutas JSON.

**Impacto**
- Se pueden sumar actividades por JSON sin tocar la arquitectura base.
- Mejora mantenibilidad de contenido.
- Facilita expansión de recorridos.

<details>
<summary>📁 Evidencia técnica</summary>

- `wiki/Contenido-JSON-Nodos.md`
- `project/sistemas/contenido/CargadorDeContenidoDeNodo.gd`
- `project/sistemas/contenido/ValidadorDeContenidoDeNodo.gd`
- `project/contenido/mapa/celiaquia_mapa.json`
- `project/niveles/nodos/celiaquia/*.json`
- Commit: `6850568` — *JSON content flow*

</details>

---

### `Falta confirmar fecha` — Validaciones de smoke y CI por objetivos
<kbd>🧪 Testing</kbd> <kbd>⚙️ CI</kbd>

Se ordenó la validación en CI para cubrir flujo jugable mínimo y salud técnica sin mezclar objetivos.

**Qué valida el smoke**
- Arranque de flujo principal y paso por mapa/gameplay.
- Nodos críticos del runtime y contratos mínimos de escena.
- Cierre y retorno en flujo de finalización.

**Qué cubre CI hoy**
- `Docs / Tracking` — trazabilidad documental en PR.
- `Technical Health` — guardrails de estructura y lint condicional.
- `Gameplay Smoke` — flujo mínimo jugable con import headless y logs.

**Qué queda fuera**
- Persistencia profunda, todos los tracks y UI fina por modalidad.

**Por qué reduce riesgo para la demo**
- Detecta temprano roturas visibles de navegación y gameplay.
- Evita merges sin documentación mínima.
- Mantiene un gate liviano para iterar sin perder control.

<details>
<summary>📁 Evidencia técnica</summary>

- `wiki/CI.md`
- `.github/workflows/docs-pr.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/gameplay-smoke-pr.yml`
- `project/tests/vertical_slice_smoke_test.gd`
- `scripts/run-godot-validation.sh`
- `scripts/run-godot-validation.ps1`

</details>

> ⚠️ **Falta confirmar:** Fecha exacta de consolidación final del esquema actual de workflows.

---

## Organizado por categoría

| Categoría | Fecha | Cambio | Descripción |
|---|---|---|---|
| 🖼️ UI | `2026-05-23` | **Barra completa al finalizar** | La barra muestra `total - 1` durante la última partida y llega al 100% al cierre del nodo. |
| ✨ UX | `2026-05-22` | **Transición partida a resultados** | El cierre del último minijuego abre resultados con transición y retorno ordenado al mapa. |
| 🖼️ UI | `2026-05-21` | **Estrellas de precisión** | Los nodos completados muestran la mejor precisión guardada mediante una estrella proporcional. |
| 🎮 Gameplay | `2026-05-20` | **Completar con opciones de palabras** | Nueva modalidad JSON integrada al routing y continuidad de partida por nodo. |
| 🐛 Bug | `2026-05-13` | **Corrección del plato** | Se ajustó la interacción de arrastre para evitar respuestas inconsistentes en intentos incorrectos. |
| 🖼️ UI | `2026-05-10` | **Barra de progreso** | El jugador ahora ve su avance dentro de la secuencia del nodo con un indicador consistente. |
| ✨ UX | `2026-05-10` | **Lección terminada / finalización de nodo** | Se agregó un cierre explícito con retorno ordenado al mapa. |
| 🎮 Gameplay | `2026-05-05` | **Partida por nodo** | Un nodo puede combinar varios juegos internos sin hardcodear escenas. |
| 🔧 Modalidad | *Falta confirmar* | **Vinculación de conceptos** | Modalidad integrada al mismo flujo de continuidad del nodo. |
| 📝 Contenido | `2026-05-03` | **Contenido JSON desacoplado** | El contenido jugable se define por JSON con contrato de carga y validación. |
| 📝 Contenido | `2026-05-13` | **Actualización de catálogo celiaquía** | Se ajustó catálogo de ítems y archivos de contenido para sostener actividades del track. |
| 💾 Persistencia | `2026-04-02` | **Persistencia local base** | Se consolidó guardado de perfil y progreso local sin backend. |
| 💾 Persistencia | `2026-04-04` | **Multi-partida interna** | El formato pasó a soportar más de una sesión por perfil. |
| 💾 Persistencia | `2026-04-06` | **Guardado parcial** | Se guarda progreso parcial para retomar actividades. |
| ⚙️ Infra | *Falta confirmar* | **Split de workflows por objetivo** | Se separó documentación, salud técnica y smoke jugable en pipelines distintos. |
| 🧪 Testing | *Falta confirmar* | **Smoke test vertical** | Se validó el flujo mínimo jugable y contratos críticos de escena/runtime. |
| 🧪 Testing | *Falta confirmar* | **Script de validación local** | Se estandarizó ejecución local por modo (`technical`, `smoke`, `ci`, `full`). |
---
