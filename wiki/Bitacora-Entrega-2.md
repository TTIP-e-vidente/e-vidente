# Bitácora — Entrega 2

[← Índice](Bitacora) · Resumen TTIP: [Entrega-2](Entrega-2)

Polish del track celiaquía, modalidad completar palabra, transiciones, estrellas y primeros tests. Más nuevo arriba.

---

### `2026-05-27` — Corregir reintento parcial en modalidad de vinculación
<kbd>Bug</kbd> <kbd>UX</kbd> <kbd>Testing</kbd>

Se corrigió el comportamiento visual de reintento en la modalidad de vinculación: al cliquear una tarjeta marcada como WRONG ahora se limpia sólo el feedback de esa tarjeta y pasa a SELECTED, sin resetear automáticamente la pareja.

**Qué problema resolvió**
- Evita que la experiencia quede confusa al tener un error.
- El usuario puede seleccionar independientemente de la columna elegida.
- Más intuitivo: antes obligaba a elegir primero izquierda y luego derecha.

**Qué se implementó**
- Ajustes en la selección: feedback local del ítem clickeado (`marcar_error(false)`) y lo marcan como `seleccionada`.
- Validación: `_validar_par_actual` marca error en ambos extremos cuando la vinculación es incorrecta, manteniendo `tiene_error` por ítem.
- Visual: `_actualizar_tarjetas` aplica estados por ítem (prioridad `seleccionada > error > vinculada > normal`) y `_dibujar_linea_de_vinculo` pinta la línea en rojo si cualquiera de los extremos está en error.
- Test: se actualizó `juego/tests/vertical_slice_smoke_test.gd` para verificar la regla WRONG + click => SELECTED (solo cambia la tarjeta clickeada).

**Impacto para el jugador**
- Reintentos más claros: tocar una tarjeta roja la convierte en amarilla; la otra permanece roja hasta que la toque o se reevalúe.
- Menos confusión visual durante reintentos.

**Evidencia técnica**
- `juego/vincular/vincular_conceptos.gd`
- `juego/vincular/concept_item.gd`
- `juego/tests/vertical_slice_smoke_test.gd`

---

### `2026-05-24` — Suite de tests unitarios para el pipeline de preguntas
<kbd>Testing</kbd> <kbd>Calidad</kbd> <kbd>Documentación</kbd>

Se creó la primera suite de tests GdUnit4 del proyecto, cubriendo el flujo completo de carga y evaluación de preguntas de opción múltiple.

**Qué problema resolvió**
- No había ningún test automatizado que verificara que el pipeline `JSON → QuestionJsonLoader → Preguntas` funcionara correctamente.
- Cambios en el loader o en los recursos `Preguntas`/`ThemePreg` podían romper la carga silenciosamente.

**Qué se implementó**
- `EvaluadorDeOpcionPregunta.gd` (`class_name EvaluadorDeOpcionPregunta`) en `juego/preguntas/` — lógica de comparación testeable sin escenas.
- `juego/tests/preguntas/carga_json_preguntas_test.gd` — 8 tests en tres fases: JSON existe, loader construye pregunta usable, evaluador clasifica cada opción.
- `juego/tests/README.md` — instalación GdUnit4 y cómo correr.
- `juego/addons/gdUnit4/` en `.gitignore` — cada dev instala el plugin localmente.
- `juego/contenido/ejemplos/quiz_choice.json` — fixture mínimo.
- `juego/niveles/nodos/ejemplos/` eliminado — ejemplos no pertenecen en `nodos/`.

**Impacto para el jugador**
- Indirecto: regresiones en carga de preguntas visibles antes de merge.

**Evidencia técnica**
- `juego/preguntas/EvaluadorDeOpcionPregunta.gd`
- `juego/tests/preguntas/carga_json_preguntas_test.gd`
- `juego/contenido/ejemplos/quiz_choice.json`

---

### `2026-05-24` — TypewriterEffect para preguntas, completar y arrastre
<kbd>UX</kbd> <kbd>Sistema</kbd> <kbd>Reutilización</kbd>

Se implementó `TypewriterEffect` como clase reutilizable (`RefCounted`) que anima texto carácter a carácter. El diseño polimórfico permite que cualquier escena la adopte sin acoplarse a un nodo específico.

**Qué problema resolvió**
- El texto de las preguntas y las frases del completar aparecían de golpe, sin transición perceptible para el jugador.

**Qué se implementó**
- `TypewriterEffect` en `juego/sistemas/`.
- Recibe un `Callable` (`aplicar_texto`) en lugar de operar directamente sobre un `Label`.
- Soporte de salto (`solicitar_salto()`) para mostrar el texto completo ante un clic o toque.
- Integrado en `pregunta.gd` y `completar_palabra.gd` (timing configurable vía `@export` en completar).

**Impacto para el jugador**
- El enunciado aparece progresivamente, dando tiempo de lectura antes de interactuar.

**Evidencia técnica**
- `juego/sistemas/TypewriterEffect.gd`
- `juego/preguntas/pregunta.gd`
- `juego/completar/completar_palabra.gd`

---

### `2026-05-23` — Barra de progreso completa antes de finalizar la última partida
<kbd>UI</kbd> <kbd>UX</kbd> <kbd>Progreso</kbd>

Se ajustó el cierre de las modalidades para que la barra llegue visualmente al 100% antes de limpiar el estado local o pasar al resultado. Animación por paso para que el salto entre etapas no sea brusco.

**Qué problema resolvió**
- La última partida podía completarse antes de que el jugador viera la barra completa, generando sensación de avance incompleto.

**Qué se implementó**
- Método explícito `completar_progreso()` en la barra compartida.
- Llamada de cierre en modalidades que limpian estado al finalizar la partida por nodo.
- Actualización visual de `Progress_Bar.tscn`.

**Impacto para el jugador**
- El final del nodo comunica mejor que la secuencia terminó.
- La transición a resultados se percibe más coherente con el avance logrado.

**Evidencia técnica**
- `juego/interface/progress_bar.gd`, `Progress_Bar.tscn`
- `juego/niveles/nivel_1/Level.gd`, `juego/preguntas/pregunta.gd`, `juego/completar/completar_palabra.tscn`

---

### `2026-05-23` — Diseño de la sección de selección de temáticas
<kbd>Diseño</kbd> <kbd>UI</kbd> <kbd>Selector</kbd>

Se diseñaron los íconos, la pantalla y los botones animados de la sección de selección de temáticas jugables, completando la identidad visual del selector con íconos únicos por temática.

**Qué problema resolvió**
- El selector usaba placeholders o íconos genéricos que no comunicaban la identidad de cada track.

**Qué se diseñó**
- Íconos por temática: Celiaquía, Veganismo, Vegan-GF, Keto, Diabetes, Autismo y candado (bloqueado).
- Pantalla y layout renovados con `botones_intro` reutilizable.
- Botones animados con variantes activa/inactiva.

**Impacto para el jugador**
- El selector comunica visualmente cada temática desde el primer vistazo.
- Botones con animación al interactuar.

**Evidencia técnica**
- `juego/niveles/selector.gd`, `selector.tscn`
- `juego/niveles/botones_intro.gd`, `botones_intro.tscn`
- Commit: `3fef3da` — *Cambios en Selector*

---

### `2026-05-22` — Transiciones suaves del juego
<kbd>UX</kbd> <kbd>Cierre</kbd> <kbd>Transición</kbd>

Se consolidaron transiciones con el flujo de `TransicionEscenas`, evitando saltos secos entre mapa, partida, racha, stats y mapa. Shader propio entre escenas.

**Qué problema resolvió**
- Cortes secos al cambiar de escena; sensación abrupta en el recorrido general.

**Qué se implementó**
- Shader GLSL (`transicion_escenas.gdshader`).
- `TransicionEscenas` como autoload.
- Uso desde `GameSceneRouter`.

**Impacto para el jugador**
- El juego se siente más ordenado y continuo entre zonas.

**Evidencia técnica**
- `juego/interface/transiciones/transicion_escenas.gd`, `.tscn`
- `juego/niveles/GameSceneRouter.gd`, `juego/niveles/global.gd`

---

### `2026-05-21` — Estrellas de precisión en el mapa
<kbd>UI</kbd> <kbd>Progreso</kbd> <kbd>Persistencia</kbd>

Se agregó estrella de progreso para que los nodos completados reflejen la mejor precisión obtenida, no solo terminado / no terminado.

**Qué problema resolvió**
- El mapa no comunicaba la calidad del desempeño en cada nodo.

**Qué se implementó**
- Componente `StarProgress` con relleno proporcional 0–1.
- Guardado de `best_accuracy` y `last_accuracy` por nodo en `SaveManager`.
- Lectura desde `MapScene` y aplicación en `LevelNode`.

**Impacto para el jugador**
- Feedback más claro: dónde jugó muy bien y dónde puede mejorar.

**Evidencia técnica**
- `juego/mapas/components/StarProgress.gd`, `.tscn`
- `juego/mapas/LevelNode.gd`, `MapScene.gd`
- `juego/interface/SaveManager.gd`
- `juego/mapas/logica/ContinuidadDePartidaDeNodo.gd`

---

### `2026-05-20` — Completar con opciones de palabras
<kbd>Gameplay</kbd> <kbd>Modalidad</kbd> <kbd>Contenido</kbd>

Se incorporó una modalidad donde el jugador completa frases eligiendo palabras disponibles.

**Qué problema resolvió**
- Sumar variedad de interacción más allá de quiz, arrastre y vinculación.

**Qué se implementó**
- Escena y script `completar_palabra` con validación, feedback de error y cierre del minijuego.
- Carga desde JSON por dificultad (`CargadorCompletar`).
- Routing por `ModalidadRouter` y `GameSceneRouter`; continuidad en `ContinuidadDePartidaDeNodo`.

**Impacto para el jugador**
- Actividad de lectura/comprensión con reintento inmediato.
- Avance del nodo consistente con el resto de modalidades.

**Evidencia técnica**
- `juego/completar/completar_palabra.gd`, `.tscn`, `CargadorCompletar.gd`
- `juego/contenido/mapa/completar_palabra.json`, `celiaquia_mapa.json`
- `juego/sistemas/ModalidadRouter.gd`, `GameSceneRouter.gd`

---

### `2026-05-20` — Jerarquización de componentes del juego (UI viva)
<kbd>Diseño</kbd> <kbd>UI</kbd> <kbd>Componente</kbd>

Se diseñaron e implementaron componentes con animaciones parametrizables para mejorar lectura de la interfaz.

**Qué problema resolvió**
- Difícil entender qué era cliqueable.
- Poca lectura rápida de qué hacer en cada pantalla.
- Pantallas muy estáticas.

**Qué se diseñó**
- Movimientos para que el juego se sienta vivo.
- Animaciones de entrada, hover y presión.
- Refactor de escenas principales; lógica centralizada por escena.

**Impacto para el jugador**
- La respuesta animada refuerza la interacción.

**Evidencia técnica**
- `juego/niveles/botones_con_movimiento.gd`, `.tscn`
- `juego/niveles/selector.gd`, `intro.gd` y `.tscn` asociados

---

### `2026-05-17` — Diseño de la modalidad "completar con opciones de palabra"
<kbd>Diseño</kbd> <kbd>UI</kbd> <kbd>Gameplay</kbd>

Se diseñó la escena visual de la modalidad de completar: layout de tarjetas, zona de respuesta y feedback gráfico antes de integrar la lógica completa.

**Qué problema resolvió**
- La modalidad no tenía escena visual definida para contenido dinámico por JSON.

**Qué se diseñó**
- `completar_palabra.tscn` con zona de respuesta y área de opciones.
- Feedback visual de error y acierto.
- Estructura lista para `CargadorCompletar`.

**Impacto para el jugador**
- Presentación clara: frase con hueco y opciones visibles.

**Evidencia técnica**
- `juego/completar/completar_palabra.tscn`, `completar_palabra.gd`
