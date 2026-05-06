# Partida por nodo

En esta iteración se consolidó el flujo donde cada nodo del mapa puede iniciar una "partida" compuesta por uno o varios juegos internos. El objetivo es que el jugador perciba cada nodo como una pequeña secuencia de desafíos con avance, feedback y enseñanza, definida por datos en JSON.

Qué problema resuelve
- Permite definir actividades reutilizables (arrastre, preguntas) desde JSON sin hardcodear la lógica en las escenas de gameplay.
- Facilita nodos con múltiples juegos internos (por ejemplo: arrastre + pregunta) para crear micro-secuencias pedagógicas.

Cómo funciona (flujo mínimo)
1. Mapa -> selección de nodo: `MapScene.al_seleccionar_nodo` usa `PlayableNodeRouter.abrir_nodo`.
2. `PlayableNodeRouter` arma la sesión jugable y el `plan_de_partida` (usando `PlanDePartidaDeNodo`) y llama a `Global.establecer_sesion_nodo_jugable_activo` + `Global.iniciar_partida_de_nodo`.
3. `ContinuidadDePartidaDeNodo.abrir_juego_actual` abre la escena de juego correspondiente (`Level.tscn` para `drag_drop`, `pregunta.tscn` para `quiz_choice`).
4. `Level` carga el contexto de juego desde `Global.obtener_juego_actual_de_partida()` o desde la sesión activa, intenta cargar JSON con `NodeContentLoader.cargar_contenido_nodo` y delega a `ManagerLevel.iniciar_desde_datos_de_arrastre` para inicializar el runtime.
5. Gameplay -> feedback/enseñanza -> `ContinuidadDePartidaDeNodo` decide avanzar o finalizar la partida.

Cómo se carga el contenido desde JSON
- Las rutas de nodo usan `res://contenido/nodos/...` y se resuelven/normalizan con `NodeContentLegacy.resolve_json_path`.
- `NodeContentLoader` valida y normaliza el JSON; para `drag_drop` extrae `content.items` y `content.targets` y genera el payload runtime.
- `ManagerLevel.iniciar_desde_datos_de_arrastre` inicializa `level_resource` y ahora también popula `active_run_data` a partir del JSON (para que el resto del runtime encuentre los metadatos de partida).

Nodos con varios juegos internos
- `PlanDePartidaDeNodo.construir_plan_de_partida` arma la lista `juegos` (cada `juego` tiene `mode`, `json_path`, `dificultad`, `titulo`, etc.).
- `Global.iniciar_partida_de_nodo` normaliza el plan y construye el `juego_actual` usado por las escenas.

Uso de la dificultad
- La dificultad puede venir del `plan_de_partida` o del JSON de nodo; `PlanDePartidaDeNodo` calcula una dificultad base y `Level`/`ManagerLevel` aplican límites para ajustar cantidad de elementos.

Archivos principales
- `project/mapas/core/PlayableNodeRouter.gd`
- `project/mapas/core/PlanDePartidaDeNodo.gd`
- `project/mapas/core/ContinuidadDePartidaDeNodo.gd`
- `project/niveles/global.gd`
- `project/niveles/nivel_1/Level.gd`
- `project/niveles/manager_level.gd`
- `project/sistemas/contenido/NodeContentLoader.gd`
- `project/contenido/mapas/celiaquia_mapa.json`

Cómo probar manualmente
- Abrir mapa (`MapScene`), seleccionar un nodo (por ejemplo `receta_1_desayuno`).
- Verificar que el `Level` se abre y muestra "Juego 1/N" en el indicador de progreso.
- Confirmar que los items/targets aparecen (arrastre) o que la pregunta carga (quiz).
- Completar el juego y comprobar que aparece la enseñanza/feedback y que la continuidad avanza o cierra según corresponda.

Decisiones de diseño
- Mantener la separación entre: (a) armado del plan desde el mapa, (b) estado global de la partida, y (c) inicialización runtime del `ManagerLevel`.
- No hardcodear datos en `Level` o `ManagerLevel`; los nodos deben poder funcionar desde JSON oficiales.
- Registrar en `Global` una sesión y una `partida_de_nodo` para que las mismas APIs sirvan tanto para juego desde mapa como para tests.

Notas de mantenimiento
- Al agregar nodos, actualizar `contenido/mapas/*.json` y añadir archivos JSON en `project/contenido/nodos/...`.
- Para debugging de carga JSON revisar `NodeContentLoader` y `NodeContentLegacy`.
