# Flujo: Mapa → Apertura de modalidad jugable

Documento de referencia para trainees. Describe qué pasa desde que el jugador
toca un nodo en el mapa hasta que aparece la primera pantalla jugable.

---

## Diagrama del flujo

```
Jugador toca nodo en el mapa
  │
  ▼
MapNode.selected.emit(node_data)
  │
  ▼
MapBoard._on_visual_node_selected(node_data)
  → MapBoard.node_selected.emit(node_data)
  │
  ▼
MapScene._on_node_selected(node_data)
  → guarda posición de scroll
  → _map_flow.seleccionar_nodo(tree, nodos_mapa, node_data)
  │
  ▼
MapFlow.seleccionar_nodo()
  ├── ¿está desbloqueado? (AvanceDeNodo.get_node_state)
  │   └── No → emit nodo_bloqueado → MapScene._on_nodo_bloqueado()
  │                                → _show_open_error("Este nodo todavía está bloqueado.")
  └── Sí → emit nodo_seleccionado → AbridorDeNodoJugable.abrir_nodo(tree, node_data)
  │
  ▼
AbridorDeNodoJugable.abrir_nodo()
  1. NodePlaySession.build_from(node_data, ruta_retorno)
  2. session.es_valida()  → fallo temprano si el nodo está mal formado
  3. NodoRuntime.iniciar_desde_sesion(tree, session)
  │
  ▼
NodoRuntime.iniciar_desde_sesion()
  1. Valida session y SceneTree
  2. ArmadorDePartida.construir_plan_de_partida(session.source_node_data)
     → devuelve { juegos: [...], dificultad, clave_pista }
  3. Global.establecer_sesion_nodo_jugable_activo(sesion)
     Global.iniciar_partida_de_nodo(plan)
     Global.establecer_sesion_de_juego(game_session_data)
  4. ContinuidadDePartidaDeNodo.abrir_juego_actual(tree, global)
  │
  ▼
ContinuidadDePartidaDeNodo.abrir_juego_actual()
  → obtiene modo del primer juego (p.ej. "quiz_choice")
  → GameSceneRouter.ir_a_modo_jugable(tree, mode)
  │
  ▼
GameSceneRouter → cambia la escena a pregunta.tscn / Level.tscn / etc.
```

> **Compatibilidad**: `NodoRuntime.iniciar(tree, node_data, return_to)` sigue existiendo y delega
> a `iniciar_desde_sesion` construyendo la sesión internamente. El trainee wrapper `iniciar_nodo()`
> también sigue disponible.

---

## Archivos involucrados y su responsabilidad

| Archivo | Qué hace en este flujo |
|---|---|
| `mapas/MapNode.gd` | Visual del nodo. Emite señal `selected` cuando el jugador hace clic. |
| `mapas/MapBoard.gd` | Contenedor visual. Retransmite `node_selected` hacia MapScene. |
| `mapas/MapScene.gd` | Coordinador de la pantalla del mapa. Conecta señales y delega en `_map_flow`. Maneja `nodo_bloqueado` con feedback al jugador. |
| `flow/map/MapFlow.gd` | Lógica de selección: verifica si el nodo está desbloqueado, luego abre. |
| `mapas/logica/AbridorDeNodoJugable.gd` | Construye `NodePlaySession` y llama a `NodoRuntime.iniciar_desde_sesion`. |
| `flow/session/NodePlaySession.gd` | Objeto de datos: describe QUÉ se va a jugar. Construido en `AbridorDeNodoJugable`. |
| `sistemas/NodoRuntime.gd` | Arma la partida, configura el estado global, abre la primera escena. |
| `mapas/logica/ArmadorDePartida.gd` | Construye la lista de juegos y el orden de la partida. |
| `mapas/logica/ContinuidadDePartidaDeNodo.gd` | Abre el juego actual y avanza entre juegos del nodo. |
| `sistemas/ModalidadRouter.gd` | Mapea el `mode` string a la escena GDScript correspondiente. |
| `flow/session/game_session_data.gd` | Objeto tipado de sesión que se guarda en Global. |

---

## Objetos de datos clave

### `MapNodeData`
Datos del nodo cargados desde el JSON del mapa.
Campos relevantes: `node_key`, `title`, `mode`, `track_key`, `games[]`, `difficulty`.

### `NodePlaySession`
Objeto tipado que describe qué se va a jugar. Construido en `AbridorDeNodoJugable` con:
```gdscript
var session := NodePlaySession.build_from(node_data, ruta_retorno)
```
Actúa como contrato entre la capa de mapa (`AbridorDeNodoJugable`) y el motor de partida
(`NodoRuntime.iniciar_desde_sesion`). Contiene: `node_key`, `mode`, `games[]`, `return_to`,
`source_node_data`.

### Plan de partida (Dictionary)
Construido por `ArmadorDePartida`. Contiene `juegos[]` (lista ordenada de actividades),
`dificultad`, `clave_pista`, `escena_de_retorno`. Se guarda en `Global`.

---

## Flujo de avance entre mini-juegos

Una vez que el jugador termina un mini-juego (ej: una pregunta):

```
pregunta.gd (o vincular_conceptos.gd, Level.gd, completar_palabra.gd)
  → NodoRuntime.finalizar_mini_juego(tree)
  → ContinuidadDePartidaDeNodo.continuar_o_finalizar_partida(tree)
      ├── ¿hay siguiente juego? → avanzar_partida_de_nodo() → abrir_juego_actual()
      └── No → registrar EXP → guardar progreso → finalizar_partida_de_nodo()
                → volver al mapa o mostrar pantalla de resultados
```

---

## Modos de juego disponibles

| `mode` en JSON | Escena que abre |
|---|---|
| `drag_drop` / `drag` / `drag_food` | `res://niveles/nivel_1/Level.tscn` |
| `quiz_choice` / `quiz` | `res://preguntas/pregunta.tscn` |
| `vinculacion_conceptos` / `match` | `res://vincular/VincularConceptos.tscn` |
| `completar_palabra` | `res://completar/completar_palabra.tscn` |

---

## Qué NO tocar si solo querés agregar un nodo nuevo

1. Editar `project/contenido/mapa/celiaquia_mapa.json` — agregar el nodo con su `node_key`, `games[]`, `map_position`, etc.
2. No hay que tocar ningún archivo de código. El flujo es completamente data-driven.

## Qué tocar si querés agregar un modo de juego nuevo

1. Crear la escena GDScript del juego.
2. Agregar el modo en `ModalidadRouter._normalizar_modo()` y `resolver_scene_path()`.
3. Agregar el caso en `ContinuidadDePartidaDeNodo._es_modo_jugable_soportado()`.
