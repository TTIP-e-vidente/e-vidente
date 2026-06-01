# Bitácora

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

### `2026-05-27` — Corregir reintento parcial en modalidad de vinculación
<kbd>Bug</kbd> <kbd>UX</kbd> <kbd>Testing</kbd>

Se corrigió el comportamiento visual de reintento en la modalidad de vinculación: al cliquear una tarjeta marcada como WRONG ahora se limpia sólo el feedback de esa tarjeta y pasa a SELECTED, sin resetear automáticamente la pareja.

**Qué problema resolvió**
- Evita que quede sea confusa la experiencia al tener un error. 
- El usuario puede seleccionar independientemente de la columna elegida. 
- Más intuitivo para el juego, anteriormente que obligabamos a seleccionar primero un concepto de la izq y luego uno de la derecha. 

**Qué se implementó**
- Ajustes en la selección: el feedback local del ítem clickeado (`marcar_error(false)`) y lo marcan como `seleccionada`.
- Validación: `_validar_par_actual` marca error en ambos extremos cuando la vinculación es incorrecta, manteniendo `tiene_error` por ítem.
- Visual: `_actualizar_tarjetas` aplica estados por ítem (prioridad `seleccionada > error > vinculada > normal`) y `_dibujar_linea_de_vinculo` pinta la línea en rojo si cualquiera de los extremos está en error.
- Test: se actualizó `project/tests/vertical_slice_smoke_test.gd` para verificar la regla WRONG + click => SELECTED (solo cambia la tarjeta clickeada).

**Impacto para el jugador**
- Reintentos más claros: tocar una tarjeta roja la convierte en amarilla, y la otra tarjeta permanece roja hasta que el jugador la toque o se reevalúe.
- Menos confusión visual durante reintentos; la validación bidireccional se mantiene.
- Juego más intuitivo y rápido. 

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

**Qué se implementó**
- `TypewriterEffect` (`extends RefCounted`, `class_name TypewriterEffect`) en `project/sistemas/`.
- Recibe un `Callable` (`aplicar_texto`) en lugar de operar directamente sobre un `Label`, lo que lo hace independiente del árbol de nodos.
- Soporte de salto (`solicitar_salto()`) para mostrar el texto completo ante un clic o toque.
- Integrado en `pregunta.gd`: anima el enunciado de cada pregunta.
- Integrado en `completar_palabra.gd`: anima la frase con blancos del ejercicio de arrastre; timing configurable vía `@export`.

**Impacto para el jugador**
- El enunciado aparece progresivamente, dando tiempo de lectura antes de que las opciones sean interactuables.

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
Se agregó una animación a cada paso de la barra de progreso para que no sea brusco el salto entre una etapa y la otra. 

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

- `project/niveles/selector.gd`
- `project/niveles/selector.tscn`
- `project/niveles/botones_intro.gd`
- `project/niveles/botones_intro.tscn`
- Commit: `3fef3da` — *Cambios en Selector*

</details>

---

### `2026-05-22` — Transiciones suaves del Juego
<kbd>UX</kbd> <kbd>Cierre</kbd> <kbd>Transición</kbd>

Se consolidaron dos tipos de transiciones usando el flujo de transición, evitando saltos secos entre juego en general, partidas, racha, stats y mapa.
Se diseñó y sumaron la transición visual entre escenas del juego, usando dos shader propios que suavizan el paso del mapa al inicio de partida y entre pantallas internas.

**Qué problema resolvió**
- El juego se sentía abrupto cuando cambiaba entre escena y escena.
- Los cambios de escena se producían con cortes secos, sin ningún tipo de transición visual.

**Qué se implementó**
- Shader GLSL personalizado (`transicion_escenas.gdshader`) para los efecto de transición.
- Uso de `TransicionEscenas` como Autoloaded.
- Uso de transiciones en  `GameSceneRouter`.

**Impacto para el jugador**
- El uso en general del juego siente más ordenada y armonioso.
- La transición refuerza la sensación de que hay un viaje entre zonas del juego.

<details>
<summary>Evidencia técnica</summary>

- `project/interface/transiciones/transicion_escenas.gd`
- `project/interface/transiciones/transicion_escenas.tscn`
- `project/niveles/GameSceneRouter.gd`
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
- El jugador puede reconocer dónde completó de manera excepcional y dónde podría mejorar.

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

Se incorporó una modalidad donde el jugador completa frases eligiendo palabras disponibles.

**Qué problema resolvió**
- Se suma una modalidad de juego para hacer más interesante el juego y la forma de interactuar con el mismo.

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

<details>
<summary>Evidencia técnica</summary>

- `project/completar/completar_palabra.tscn`
- `project/completar/completar_palabra.gd`

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

</details>

---

### `2026-20-05` — Jerarquización de componentes del juego
<kbd>Diseño</kbd> <kbd>UI</kbd> <kbd>Componente</kbd>

Se diseñaron, jerarquizaron e implementaron diferentes componentes clave para la buena lectura de la interfaz.


**Qué problema resolvió**
- Era dificultoso entender qué era cliqueable y qué no.
- No había una rápida lectura de qué había que hacer en cada pantalla. 
- Situación estática en la pantalla. 

**Qué se diseñó**
- Movimientos clave para que el juego parezca VIVO. 
- Componentes con animaciones parametrizables de entrada, hover y presión.
- Refactor de la totalidad de escenas del juego. 
- Lógica de animación centralizada y configurable por escena.

**Impacto para el jugador**
- La respuesta animada refuerza la interacción y la sensación de juego.

<details>
<summary>Evidencia técnica</summary>

- `project/niveles/botones_con_movimiento.gd`
- `project/niveles/botones_con_movimiento.tscn`
- `project/niveles/selector.gd`
- `project/niveles/selector.tscn`
- `project/niveles/intro.gd`
- `project/niveles/intro.tscn`


</details>

---




---

### `Falta confirmar fecha` — Validaciones y Tests
<kbd>Testing</kbd> <kbd>CI</kbd>

Se ordenó la validación en CI para cubrir flujo jugable mínimo y salud técnica.

**Qué valida**
- Arranque de flujo principal y paso por mapa/gameplay.
- Nodos críticos del runtime y contratos mínimos de escena.
- Cierre y retorno en flujo de finalización.

**Qué cubre hoy**
- `Docs / Tracking` — trazabilidad documental en PR.
- `Technical Health` — guardrails de estructura y lint condicional.
- `Gameplay Smoke` — flujo mínimo jugable con import headless y logs.

**Por qué reduce riesgo**
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

---
