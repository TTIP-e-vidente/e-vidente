# Flujo Funcional del Mapa — E-VIDENTE

> **Audiencia:** trainee / nuevo integrante.
> **Regla de lectura:** si querés cambiar algo, mirá la tabla al final.
> Si querés entender cómo funciona, leé el flujo de 10 pasos.

---

## Parte A — Flujo del mapa en 10 pasos

El camino desde el JSON hasta que el jugador ve los nodos en pantalla es lineal.
Cada número = un archivo con una sola responsabilidad.

    1. celiaquia_mapa.json
       Define qué nodos existen, en qué orden y qué juegos contienen.
       Define el bloque layout (route_id y placement_mode).
       No define posiciones x/y por nodo.

    2. CargadorDeMapa.gd
       Lee el JSON. Valida que tenga id, track_key, title y nodes[].
       Por cada nodo: MapNodeData.from_json() → objeto de datos.
       Parsea el bloque layout → MapLayoutConfig.
       Devuelve Array[MapNodeData] + MapLayoutConfig, ordenados por índice del JSON.

    3. MapNodeData.gd
       Representa un nodo jugable: node_key, título, games[], shuffle_games, etc.
       Solo datos. No sabe de posiciones, pantalla ni progreso.

    4. MapScene._ready()
       Llama cargar_mapa() → guarda nodos_mapa: Array[MapNodeData] + layout_config.
       Luego llama actualizar_estados_de_nodos().

    5. MapScene.actualizar_estados_de_nodos()
       Paso 1: lee SaveManager.get_all_node_progress() → sincroniza con Global.
       Paso 2: por cada nodo llama AvanceDeNodo.get_node_state()
               → construye node_states: Array[Dictionary]
               cada Dictionary tiene: is_unlocked, is_completed, visual_state, best_percent.
       Llama MapBoard.configurar_nodos(nodos_mapa, node_states, layout_config).

    6. AvanceDeNodo.gd
       Calcula el estado de cada nodo:
       - is_completed: Global.es_nodo_jugable_completado(track_key, node_key)
       - is_unlocked:  el nodo anterior está completado (o es default_unlocked)
       - visual_state: completed | available | locked
       No toca SaveManager ni la pantalla.

    7. MapBoard.configurar_nodos(nodos_mapa, node_states, layout_config)
       Ordena los nodos visuales por nivel_id.
       Pide posiciones: MapNodePositionResolver.resolve(Contenido, layout_config, 30)
       Mueve cada nodo visual: visual_node.position = layout_pos[i] - contenedor.position
       Por cada par (nodo_data, nodo_visual):
       - Llama visual_node.configurar(node_data, node_state).
       - Conecta la señal selected del LevelNode.

    8. Pipeline de layout automatico (activo — placement_mode = anchors)
       MapLayoutConfig        ← parseado desde layout en el JSON
       MapRouteRegistry       ← busca Path2D RutaCeliaquia1 dentro de Contenido
       MapPathLayout          ← devuelve curve.get_point_position(i) para cada nodo i
       MapNodePositionResolver← combina los tres: devuelve Array[Vector2] en espacio Contenido

    9. LevelNode.configurar(node_data, node_state)
       Aplica node_key, title, visual_state (locked/available/completed).
       Pinta ícono, estrella de precisión y color segun estado.
       No consulta SaveManager. No calcula posiciónes.

    10. LevelNode — el jugador ve el nodo en pantalla.
        Al tocar → emite la señal selected(node_data).

---

## Parte B — Responsabilidades por archivo

### CargadorDeMapa.gd
**Responsabilidad:** leer y validar el JSON. Construir Array[MapNodeData] + MapLayoutConfig.
**No hace:** calcular posiciónes, saber si un nodo esta bloqueado, abrir escenas.

### MapNodeData.gd
**Responsabilidad:** representar los datos de un nodo: node_key, title, games[], shuffle_games, track_key, mode.
**No hace:** calcular nada, saber de pantalla o progreso, leer SaveManager.

### MapScene.gd
**Responsabilidad:** dueño visual del mapa. Orquesta la carga, el cálculo de estados y el retorno desde un juego.
**No hace:** renderizar nodos, calcular posiciónes, abrir escenas sin pasar por AbridorDeNodoJugable.

### MapBoard.gd
**Responsabilidad:** renderizar nodos en pantalla. Configurar cada LevelNode con datos y estado. Manejar scroll.
**No hace:** leer JSON, calcular estados de progreso, decidir modalidad, abrir escenas.

### MapLayoutConfig.gd
**Responsabilidad:** leer route_id, placement_mode, spacing_mode, spacing_factor, márgenes.
**No hace:** calcular posiciónes, buscar nodos, tocar escenas.

### MapRouteRegistry.gd
**Responsabilidad:** buscar un Path2D por nombre dentro del contenedor padre.
**No hace:** calcular posiciónes, tocar nodos visuales.

### MapNodePositionResolver.gd
**Responsabilidad:** elegir entre modo anchors y modo curve, delegar en MapPathLayout.
**No hace:** matemática de posiciónes, instanciar nodos, leer JSON.

### MapPathLayout.gd
**Responsabilidad:** unico lugar con matemática de posiciónes. Modo anchors: get_point_position(i). Modo curve: sample_baked().
**No hace:** conocer MapBoard, conocer LevelNode, leer JSON.

### DebugLayoutOverlay.gd
**Responsabilidad:** dibujar circulos de debug en cada posición calculada. Apagado por default (debug_layout = false).
**No hace:** nada en produccion.

### LevelNode.gd
**Responsabilidad:** pintar un nodo visual con su estado, estrella de precisión y título.
**No hace:** consultar SaveManager, calcular posiciónes, saber de partidas o modalidades.

### AvanceDeNodo.gd
**Responsabilidad:** calcular si un nodo esta bloqueado, disponible o completado.
**No hace:** abrir escenas, renderizar, guardar progreso.

### AbridorDeNodoJugable.gd
**Responsabilidad:** punto de entrada para abrir un nodo. Llama NodoRuntime.iniciar().
**No hace:** saber qué modalidad se juega, calcular posiciónes, leer SaveManager.

### NodoRuntime.gd
**Responsabilidad:** iniciar una partida completa. Arma el plan, establece sesión en Global, abre el primer juego.
**No hace:** renderizar el mapa, calcular estados visuales, navegar directamente.

### ArmadorDePartida.gd
**Responsabilidad:** construir la lista de juegos para un nodo (plan.juegos[]). Maneja fijos, random, anti-repetición y shuffle.
**No hace:** abrir escenas, guardar progreso, saber de EXP.

---

## Parte C — Reglas de layout

    Índice    = posición visual. El nodo i en el array usa el punto i de RutaCeliaquia1.
    node_key  = identidad / progreso / estado. No cambia si el nodo se mueve de lugar.
    anchors   = posiciónes diseñadas: cada punto de RutaCeliaquia1 es exactamente un nodo.
    curve     = distribución automatica por distancia recorrida sobre la curva.

### placement_mode = anchors (activo en celiaquia_mapa.json)

    Nodo 0 (Receta1)    → RutaCeliaquia1.get_point_position(0)  = (908, 99)
    Nodo 1 (Pregunta1)  → RutaCeliaquia1.get_point_position(1)  = (752, 173)
    ...
    Nodo 29 (Pregunta24)-> RutaCeliaquia1.get_point_position(29) = (586, 2129)

Para mover un nodo del mapa: editar el punto correspondiente en RutaCeliaquia1.

### placement_mode = curve (disponible)

Los nodos se distribuyen uniformemente por largo de curva usando sample_baked().
Usar si la curva tiene mas o menos puntos qué nodos.

---

## Parte D — Flujo de estados

    1. MapScene.actualizar_estados_de_nodos()
       → lee SaveManager.get_all_node_progress()
       → por cada nodo: AvanceDeNodo.get_node_state(nodos_mapa, node_data)

    2. AvanceDeNodo.get_node_state()
       → is_completed: Global.es_nodo_jugable_completado(track_key, node_key)
       → is_unlocked:
           - Nodo 0: siempre desbloqueado
           - Nodo N: desbloqueado si el nodo N-1 esta completado
       → visual_state: completed | available | locked

    3. MapScene arma node_states: Array[Dictionary] (mismo orden qué nodos_mapa)

    4. MapBoard.configurar_nodos(nodos_mapa, node_states)
       → visual_node.configurar(node_data, node_states[index])

    5. LevelNode.configurar(node_data, node_state)
       → pinta el estado que recibe — no recalcula nada

---

## Parte E — Click del jugador y apertura de partida

    Jugador toca nodo
      → LevelNode emite selected(node_data)
      → MapBoard re-emite node_selected(node_data)
      → MapScene.al_seleccionar_nodo(node_data)
          → guarda scroll actual
          → FlujoDeNodoJugable.seleccionar_nodo()
              → AvanceDeNodo.get_node_state()  [es_unlocked?]
              → bloqueado  → emite apertura_fallida (silencioso)
              → disponible → AbridorDeNodoJugable.abrir_nodo()
                                 → NodoRuntime.iniciar()
                                     → ArmadorDePartida.construir_plan_de_partida()
                                         → juegos fijos o random desde games[]
                                         → aplica shuffle_games si corresponde
                                         → anti-repetición
                                     → guarda plan + sesión en Global
                                     → ContinuidadDePartidaDeNodo.abrir_juego_actual()
                                         → ModalidadRouter.abrir_modalidad()
                                             → drag_drop             → Level.tscn
                                             → quiz_choice           → pregunta.tscn
                                             → vinculacion_conceptos → VincularConceptos.tscn
                                             → completar_palabra     → completar_palabra.tscn

    Jugador termina minijuego
      → NodoRuntime.avanzar_actividad()
      → ContinuidadDePartidaDeNodo.continuar_o_finalizar_partida()
          → otro juego en el plan → avanzar → abrir_juego_actual()
          → ultimo juego          → guardar precisión → registrar EXP
                                  → finalizacion_partida.tscn
                                  → luego MapScene.volver_al_mapa()
                                    → actualizar_estados_de_nodos()
                                    → desplazar_al_primer_nodo_disponible()

**Regla:** el mapa no decide qué minijuego se abre.
La modalidad viene de games[] en el JSON y de ArmadorDePartida. El mapa solo transmite el node_data.

---

## Tabla si quiero cambiar X, voy a Y

| Quiero cambiar... | Voy a... |
|---|---|
| Datos del mapa (nodos, juegos, orden) | contenido/mapa/celiaquia_mapa.json |
| Ruta activa del layout | celiaquia_mapa.json > layout.route_id |
| Modo de posiciónamiento | celiaquia_mapa.json > layout.placement_mode |
| Posición de un nodo del mapa (modo anchors) | punto correspondiente en RutaCeliaquia1 (MapBoard.tscn) |
| Distribucion genérica (modo curve) | spacing_factor, start_margin, end_margin en el JSON |
| Algoritmo de layout | mapas/layout/MapPathLayout.gd |
| Como se leé el JSON | mapas/logica/CargadorDeMapa.gd |
| Datos de un nodo (agregar campo) | mapas/core/MapNodeData.gd |
| El estado locked/available/completed | mapas/logica/AvanceDeNodo.gd |
| Render de nodos (iteracion, señales) | mapas/MapBoard.gd |
| Visual del nodo (ícono, estrella, color) | mapas/LevelNode.gd |
| Apertura de partida desde el mapa | mapas/logica/AbridorDeNodoJugable.gd |
| Armado de juegos del nodo | mapas/logica/ArmadorDePartida.gd |
| Escena que abre segun modalidad | sistemas/ModalidadRouter.gd |
| Avance entre minijuegos | mapas/logica/ContinuidadDePartidaDeNodo.gd |
| Navegacion entre escenas | niveles/GameSceneRouter.gd |
| EXP y formula de recompensa | sistemas/NodoProgressionRules.gd |

---

## Tests

    .\scripts\run-godot-validation.ps1 -Mode smoke
    → Validacion Godot completada correctamente. — ExitCode 0
