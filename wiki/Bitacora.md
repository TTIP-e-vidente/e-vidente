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

---

## Lo que pasó recientemente

Acá están los cambios más nuevos y relevantes para demo, defensa TTIP y continuidad técnica.

---

### `2026-05-27` — Corregir reintento parcial en modalidad de vinculación
<kbd>Bug</kbd> <kbd>UX</kbd> <kbd>Testing</kbd>

Se corrigió el comportamiento visual de reintento en la modalidad de vinculación: al clicar una tarjeta marcada como WRONG ahora se limpia sólo el feedback de esa tarjeta y pasa a SELECTED, sin resetear automáticamente la pareja.

**Qué problema resolvió**
- Evita que tocar un extremo rojo borre el estado del otro extremo, lo que generaba confusión en el jugador.

**Qué se implementó**
- Ajustes en la selección: `_seleccionar_tarjeta_izquierda` y `_seleccionar_tarjeta_derecha` ahora limpian solo el feedback local del ítem clickeado (`marcar_error(false)`) y lo marcan como `seleccionada`.
- Validación: `_validar_par_actual` marca error en ambos extremos cuando la vinculación es incorrecta, manteniendo `tiene_error` por ítem.
- Visual: `_actualizar_tarjetas` aplica estados por ítem (prioridad `seleccionada > error > vinculada > normal`) y `_dibujar_linea_de_vinculo` pinta la línea en rojo si cualquiera de los extremos está en error.
- Test: se actualizó `project/tests/vertical_slice_smoke_test.gd` para verificar la regla WRONG + click => SELECTED (solo cambia la tarjeta clickeada).

**Impacto para el jugador**
- Reintentos más claros: tocar una tarjeta roja la convierte en amarilla, y la otra tarjeta permanece roja hasta que el jugador la toque o se reevalúe.
- Menos confusión visual durante reintentos; la validación bidireccional se mantiene.

**Evidencia técnica**
- `project/vincular/vincular_conceptos.gd`
- `project/vincular/concept_item.gd`
- `project/tests/vertical_slice_smoke_test.gd`


### `2026-05-24` — Suite de tests unitarios para el pipeline de preguntas
<kbd>Testing</kbd> <kbd>Calidad</kbd> <kbd>Documentación</kbd>

Se creó la primera suite de tests GdUnit4 del proyecto, cubriendo el flujo completo de carga y evaluación de preguntas de opción múltiple.

**Qué problema resolvió**
- No había ningún test automatizado que verificara que el pipeline `JSON → QuestionJsonLoader → Preguntas` funcionara correctamente.
- Cambios en el loader o en los recursos `Preguntas`/`ThemePreg` podían romper la carga silenciosamente.

**Qué se implementó**
- `EvaluadorDeOpcionPregunta.gd` (`extends RefCounted`, `class_name EvaluadorDeOpcionPregunta`) en `project/preguntas/` — extrae la lógica de comparación de respuestas para poder testearla sin escenas.
- `project/tests/preguntas/carga_json_preguntas_test.gd` — 8 tests en tres fases: el JSON existe, el loader construye una pregunta usable, el evaluador clasifica correctamente cada opción.
- `project/tests/README.md` — instrucciones de instalación de GdUnit4 (AssetLib o GitHub), cómo correr los tests y tabla descriptiva de los 8 tests.
- `project/addons/gdUnit4/` agregado al `.gitignore` — cada desarrollador instala el plugin localmente.
- `project/contenido/ejemplos/quiz_choice.json` — fixture mínimo para los tests, en `contenido/` donde corresponde.
- `project/niveles/nodos/ejemplos/` eliminado — los ejemplos no pertenecen en `nodos/`.

**Impacto para el jugador**
- Indirecto: los tests hacen visible cualquier regresión en la carga de preguntas antes de que llegue a producción.

<details>
<summary>Evidencia técnica</summary>

- `project/preguntas/EvaluadorDeOpcionPregunta.gd`
- `project/tests/preguntas/carga_json_preguntas_test.gd`
- `project/tests/README.md`
- `project/contenido/ejemplos/quiz_choice.json`

</details>

---

### `2026-05-24` — TypewriterEffect para preguntas, completar y arrastre
<kbd>UX</kbd> <kbd>Sistema</kbd> <kbd>Reutilización</kbd>

Se implementó `TypewriterEffect` como clase reutilizable (`RefCounted`) que anima texto carácter a carácter. El diseño polimórfico permite que cualquier escena la adopte sin acoplarse a un nodo específico.

**Qué problema resolvió**
- El texto de las preguntas y las frases del completar aparecían de golpe, sin transición perceptible para el jugador.
- No había forma compartida de cancelar una animación en curso cuando el jugador adelantaba la pantalla.

**Qué se implementó**
- `TypewriterEffect` (`extends RefCounted`, `class_name TypewriterEffect`) en `project/sistemas/`.
- Recibe un `Callable` (`aplicar_texto`) en lugar de operar directamente sobre un `Label`, lo que lo hace independiente del árbol de nodos.
- Cancela automáticamente la animación anterior al llamar `iniciar()` de nuevo, usando un contador de versión interno (`_id_llamada_vigente`).
- Soporte de salto (`solicitar_salto()`) para mostrar el texto completo ante un clic o toque.
- Integrado en `pregunta.gd`: anima el enunciado de cada pregunta.
- Integrado en `completar_palabra.gd`: anima la frase con blancos del ejercicio de arrastre; timing configurable vía `@export`.

**Impacto para el jugador**
- El enunciado aparece progresivamente, dando tiempo de lectura antes de que las opciones sean interactuables.
- Un toque omite la animación sin romper el flujo.
- Ambas modalidades se comportan de forma coherente con la misma lógica subyacente.

<details>
<summary>Evidencia técnica</summary>

- `project/sistemas/TypewriterEffect.gd`
- `project/preguntas/pregunta.gd` — `var _typewriter: TypewriterEffect`
- `project/completar/completar_palabra.gd` — `_renderizar_frase_con_typewriter()`, `_configurar_typewriter()`

</details>

---

### `2026-05-23` — Barra de progreso completa antes de finalizar la última partida
<kbd>UI</kbd> <kbd>UX</kbd> <kbd>Progreso</kbd>

Se ajustó el cierre de las modalidades para que la barra llegue visualmente al 100% antes de limpiar el estado local o pasar al resultado.

**Qué problema resolvió**
- La última partida podía completarse antes de que el jugador viera la barra completa, generando una sensación de avance incompleto.

**Qué se implementó**
- Método explícito `completar_progreso()` en la barra compartida.
- Llamada de cierre en modalidades que limpian estado al finalizar la partida por nodo.
- Actualización visual de `Progress_Bar.tscn` para sostener el indicador inferior.

**Impacto para el jugador**
- El final del nodo comunica mejor que la secuencia terminó.
- La transición a resultados se percibe más coherente con el avance logrado.

<details>
<summary>Evidencia técnica</summary>

- `project/interface/progress_bar.gd`
- `project/interface/Progress_Bar.tscn`
- `project/niveles/nivel_1/Level.gd`
- `project/preguntas/pregunta.gd`
- `project/completar/completar_palabra.tscn`

</details>

---

### `2026-05-23` — Diseño de la sección de selección de temáticas
<kbd>Diseño</kbd> <kbd>UI</kbd> <kbd>Selector</kbd>

Se diseñaron los íconos, la pantalla y los botones animados de la sección de selección de temáticas jugables, completando la identidad visual del selector con íconos únicos por temática.

**Qué problema resolvió**
- El selector de temáticas usaba placeholders o íconos genéricos que no comunicaban la identidad de cada track.

**Qué se diseñó**
- Íconos únicos por temática: Celiaquía, Veganismo, Vegan-GF, Keto, Diabetes, Autismo y candado (bloqueado).
- Pantalla y layout de selector renovados con componente `botones_intro` reutilizable.
- Botones animados con variantes activa/inactiva.

**Impacto para el jugador**
- El selector comunica visualmente la identidad de cada temática desde el primer vistazo.
- Los botones responden con animación al interactuar, reforzando la sensación táctil.
- La pantalla queda coherente con el resto del sistema visual del juego.

<details>
<summary>Evidencia técnica</summary>

- `project/assets-sistema/selector/celiaquia-selector.png`
- `project/assets-sistema/selector/vegan-selector.png`
- `project/assets-sistema/selector/vegan-gf-selector.png`
- `project/assets-sistema/selector/keto-selector.png`
- `project/assets-sistema/selector/diabetes-selector.png`
- `project/assets-sistema/selector/autismo-selector.png`
- `project/assets-sistema/selector/candado-selector.png`
- `project/niveles/selector.gd`
- `project/niveles/selector.tscn`
- `project/niveles/botones_intro.gd`
- `project/niveles/botones_intro.tscn`
- Commit: `3fef3da` — *Cambios en Selector*

</details>

---

### `2026-05-22` — Transición suave de partida a resultados
<kbd>UX</kbd> <kbd>Cierre</kbd> <kbd>Transición</kbd>

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
<summary>Evidencia técnica</summary>

- `project/interface/transiciones/transicion_escenas.gd`
- `project/interface/transiciones/transicion_escenas.tscn`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/MapScene.gd`
- `project/mapas/Finalización-Partida.tscn`
- `project/mapas/finalización_partida.gd`
- `project/niveles/global.gd`

</details>

---

### `2026-05-21` — Estrellas de precisión en el mapa
<kbd>UI</kbd> <kbd>Progreso</kbd> <kbd>Persistencia</kbd>

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
<summary>Evidencia técnica</summary>

- `project/mapas/components/StarProgress.gd`
- `project/mapas/components/StarProgress.tscn`
- `project/mapas/LevelNode.gd`
- `project/mapas/MapScene.gd`
- `project/interface/SaveManager.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
</details>

---

### `2026-05-20` — Completar con opciones de palabras
<kbd>Gameplay</kbd> <kbd>Modalidad</kbd> <kbd>Contenido</kbd>

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
<summary>Evidencia técnica</summary>

- `project/completar/completar_palabra.gd`
- `project/completar/completar_palabra.tscn`
- `project/completar/CargadorCompletar.gd`
- `project/contenido/mapa/completar_palabra.json`
- `project/contenido/mapa/celiaquia_mapa.json`
- `project/sistemas/ModalidadRouter.gd`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/tests/vertical_slice_smoke_test.gd`

</details>

---

### `2026-05-17` — Diseño de la modalidad "completar con opciones de palabra"
<kbd>Diseño</kbd> <kbd>UI</kbd> <kbd>Gameplay</kbd>

Se diseñó la escena visual de la modalidad de completar, estableciendo el layout de tarjetas de palabras, zona de respuesta y feedback gráfico que luego integró la lógica de juego.

**Qué problema resolvió**
- La modalidad de completar no tenía una escena visual definida que pudiera recibir contenido dinámico por JSON.

**Qué se diseñó**
- Escena base `completar_palabra.tscn` con zona de respuesta y área de opciones de palabras.
- Layout con feedback visual de error y acierto.
- Estructura visual preparada para recibir contenido dinámico desde `CargadorCompletar`.

**Impacto para el jugador**
- La actividad tiene una presentación clara: el jugador ve la frase con espacio vacío y las opciones disponibles.
- El diseño sostiene el reintento sin romper el flujo visual.

<details>
<summary>Evidencia técnica</summary>

- `project/completar/completar_palabra.tscn`
- `project/completar/completar_palabra.gd`
- Commit: `45aefa9` — *Sumo escena modalidad Completar*

</details>

---

### `2026-05-17` — Diseño e implementación de la transición suave entre escenas
<kbd>Diseño</kbd> <kbd>UX</kbd> <kbd>Transición</kbd>

Se diseñó y sumó la transición visual entre escenas del juego, usando un shader propio que suaviza el paso del mapa al inicio de partida y entre pantallas internas.

**Qué problema resolvió**
- Los cambios de escena se producían con cortes secos, sin ningún tipo de transición visual.

**Qué se diseñó e implementó**
- Escena `transicion_escenas.tscn` con animación de apertura y cierre.
- Shader GLSL personalizado (`transicion_escenas.gdshader`) para el efecto de transición.
- Integración inicial en la escena de intro para validar el flujo.

**Impacto para el jugador**
- El paso entre pantallas deja de sentirse abrupto.
- La transición refuerza la sensación de que hay un viaje entre zonas del juego.

<details>
<summary>Evidencia técnica</summary>

- `project/interface/transicion_escenas.tscn`
- `project/interface/transicion_escenas.gd`
- `project/interface/transicion_escenas.gdshader`
- `project/niveles/intro.gd`
- `project/niveles/intro.tscn`
- Commit: `66bb4c9` — *Sumo la transición entre escenas*

</details>

---

### `2026-05-16` — Integración de vinculacion-partidaxnodo en dev y apertura de PR a main
<kbd>Integración</kbd> <kbd>Limpieza</kbd> <kbd>PR</kbd>

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
<summary>Evidencia técnica</summary>

- `project/items/ItemLevel.gd` — eliminación de funciones duplicadas
- `.githooks/commit-msg` — hook preventivo co-author
- PR activa: [Dev #24](https://github.com/TTIP-e-vidente/e-vidente/pull/24)
- Commits de merge: `b585fd6`, `8419e05`

</details>

---

### `2026-05-13` — Corrección del comportamiento del plato
<kbd>Bug</kbd> <kbd>Gameplay</kbd>

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
<summary>Evidencia técnica</summary>

- `project/items/ItemLevel.gd`
- `project/niveles/manager_level.gd`
- Commit: `7738db4` — *Resuelvo bug del plato*

</details>
---

### `2026-05-10` — Barra de progreso durante la actividad
<kbd>UI</kbd> <kbd>Progreso</kbd>

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
<summary>Evidencia técnica</summary>

- `project/interface/progress_bar.gd`
- `project/interface/Progress_Bar.tscn`
- `project/preguntas/pregunta.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/niveles/nivel_1/Level.gd`
- Commit: `e02c1d8` — *Feature/barra progreso*

</details>

---

### `2026-05-10` — Estado de lección terminada y finalización de nodo
<kbd>UX</kbd> <kbd>Cierre</kbd>

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
<summary>Evidencia técnica</summary>

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
<kbd>Gameplay</kbd> <kbd>Modalidad</kbd>

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
<summary>Evidencia técnica</summary>

- `project/sistemas/ModalidadRouter.gd`
- `project/niveles/GameSceneRouter.gd`
- `project/mapas/logica/ContinuidadDePartidaDeNodo.gd`
- `project/vincular/vincular_conceptos.gd`
- `project/vincular/VincularConceptos.tscn`
- `project/tests/vertical_slice_smoke_test.gd`
- `project/contenido/mapa/vinculaciones.json`

</details>

>  **Falta confirmar:** Fecha única de corte para declarar la modalidad como cerrada en todos los tracks.

---

### `2026-05-05` — Diseño del componente principal para el botón JUGAR
<kbd>Diseño</kbd> <kbd>UI</kbd> <kbd>Componente</kbd>

Se diseñó y parametrizó el componente de botón animado reutilizable que sirve como base visual del botón JUGAR y otros botones clave de la interfaz.

**Qué problema resolvió**
- Cada escena replicaba su propio botón animado sin un componente común, generando duplicación visual e inconsistencia de comportamiento entre pantallas.

**Qué se diseñó**
- Componente `botones_con_movimiento` con animaciones parametrizables de entrada, hover y presión.
- Refactor del selector y la intro para usar el nuevo componente compartido.
- Lógica de animación centralizada y configurable por escena.

**Impacto para el jugador**
- El botón JUGAR y los botones del selector tienen comportamiento visual consistente.
- La respuesta animada refuerza la interacción y la sensación de juego.

<details>
<summary>Evidencia técnica</summary>

- `project/niveles/botones_con_movimiento.gd`
- `project/niveles/botones_con_movimiento.tscn`
- `project/niveles/selector.gd`
- `project/niveles/selector.tscn`
- `project/niveles/intro.gd`
- `project/niveles/intro.tscn`
- Commit: `9d65819` — *Parametrizado de juego*

</details>

---

### `2026-05-05` — Partida por nodo con múltiples juegos internos
<kbd>Gameplay</kbd> <kbd>Arquitectura</kbd>

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
<summary>Evidencia técnica</summary>

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
<kbd>Contenido</kbd>

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
<summary>Evidencia técnica</summary>

- `wiki/Contenido-JSON-Nodos.md`
- `project/sistemas/contenido/CargadorDeContenidoDeNodo.gd`
- `project/sistemas/contenido/ValidadorDeContenidoDeNodo.gd`
- `project/contenido/mapa/celiaquia_mapa.json`
- `project/niveles/nodos/celiaquia/*.json`
- Commit: `6850568` — *JSON content flow*

</details>

---

### `Falta confirmar fecha` — Validaciones de smoke y CI por objetivos
<kbd>Testing</kbd> <kbd>CI</kbd>

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
<summary>Evidencia técnica</summary>

- `wiki/CI.md`
- `.github/workflows/docs-pr.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/gameplay-smoke-pr.yml`
- `project/tests/vertical_slice_smoke_test.gd`
- `scripts/run-godot-validation.sh`
- `scripts/run-godot-validation.ps1`

</details>

>  **Falta confirmar:** Fecha exacta de consolidación final del esquema actual de workflows.

---

## Organizado por categoría

| Categoría | Fecha | Cambio | Descripción |
|---|---|---|---|
|  UI | `2026-05-23` | **Barra completa antes de finalizar** | La barra llega al 100% antes de limpiar estado o pasar a resultados en el cierre del nodo. |
|  Diseño | `2026-05-23` | **Selección de temáticas – diseño** | Íconos únicos por temática, pantalla selector y botones animados renovados. |
|  UX | `2026-05-22` | **Transición partida a resultados** | El cierre del último minijuego abre resultados con transición y retorno ordenado al mapa. |
|  UI | `2026-05-21` | **Estrellas de precisión** | Los nodos completados muestran la mejor precisión guardada mediante una estrella proporcional. |
|  Gameplay | `2026-05-20` | **Completar con opciones de palabras** | Nueva modalidad JSON integrada al routing y continuidad de partida por nodo. |
|  Diseño | `2026-05-17` | **Completar con palabras – diseño** | Escena visual de la modalidad con layout de opciones y feedback gráfico. |
|  Diseño | `2026-05-17` | **Transición de escenas – diseño** | Shader y escena de transición suave entre mapa y partida. |
|  Bug | `2026-05-13` | **Corrección del plato** | Se ajustó la interacción de arrastre para evitar respuestas inconsistentes en intentos incorrectos. |
|  UI | `2026-05-10` | **Barra de progreso** | El jugador ahora ve su avance dentro de la secuencia del nodo con un indicador consistente. |
|  UX | `2026-05-10` | **Lección terminada / finalización de nodo** | Se agregó un cierre explícito con retorno ordenado al mapa. |
|  Diseño | `2026-05-05` | **Botón JUGAR – componente** | Componente reutilizable con animación para el botón de inicio de partida y selector. |
|  Gameplay | `2026-05-05` | **Partida por nodo** | Un nodo puede combinar varios juegos internos sin hardcodear escenas. |
|  Modalidad | *Falta confirmar* | **Vinculación de conceptos** | Modalidad integrada al mismo flujo de continuidad del nodo. |
|  Contenido | `2026-05-03` | **Contenido JSON desacoplado** | El contenido jugable se define por JSON con contrato de carga y validación. |
|  Contenido | `2026-05-13` | **Actualización de catálogo celiaquía** | Se ajustó catálogo de ítems y archivos de contenido para sostener actividades del track. |
|  Persistencia | `2026-04-02` | **Persistencia local base** | Se consolidó guardado de perfil y progreso local sin backend. |
|  Persistencia | `2026-04-04` | **Multi-partida interna** | El formato pasó a soportar más de una sesión por perfil. |
|  Persistencia | `2026-04-06` | **Guardado parcial** | Se guarda progreso parcial para retomar actividades. |
|  Infra | *Falta confirmar* | **Split de workflows por objetivo** | Se separó documentación, salud técnica y smoke jugable en pipelines distintos. |
|  Testing | *Falta confirmar* | **Smoke test vertical** | Se validó el flujo mínimo jugable y contratos críticos de escena/runtime. |
|  Testing | *Falta confirmar* | **Script de validación local** | Se estandarizó ejecución local por modo (`technical`, `smoke`, `ci`, `full`). |
---
