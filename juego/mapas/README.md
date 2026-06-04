# Mapas

Orquestación del tablero y apertura de nodos. **Contenido JSON** (activities, `games`, catálogo): [contenido/README](../contenido/README.md). Estado del repo: [ESTADO-ACTUAL](../../ESTADO-ACTUAL.md).

## Empeza por aca

La ruta principal para entender el mapa es:

1. `MapScene.gd`
2. `logica/CargadorDeMapa.gd`
3. `core/MapNodeData.gd`
4. `logica/AvanceDeNodo.gd`
5. `MapBoard.gd`
6. `LevelNode.gd`
7. `logica/AbridorDeNodoJugable.gd`
8. `logica/ArmadorDePartida.gd`
9. `logica/ContinuidadDePartidaDeNodo.gd`

## Flujo trainee del mapa

1. `CargadorDeMapa.gd` lee `res://contenido/mapa/celiaquia_mapa.json`.
2. `MapNodeData.gd` representa cada nodo como un dato simple.
3. `ArmadorDePartida.gd` arma la secuencia final del nodo.
4. Si `games` trae objetos random, ahi mismo resuelve activity_id por `type` y `difficulty`.
5. Si `shuffle_games` es `true`, mezcla una copia de la secuencia final.
6. `AbridorDeNodoJugable.gd` abre el juego actual del plan.
7. `NodeContentLoader.gd` busca la `activity_id` en `arrastres.json`, `preguntas.json` o `vinculaciones.json`.
8. `ActivityAdapter.gd` adapta la activity al formato del minijuego.
9. `ContinuidadDePartidaDeNodo.gd` pasa al siguiente game o cierra el nodo.
10. `AvanceDeNodo.gd` consulta el progreso guardado para desbloqueo y completado.

`MapScene.gd`, `MapBoard.gd` y `LevelNode.gd` siguen siendo la capa visual y de interacción.

## Responsabilidades

- `MapScene.gd`: pantalla principal del mapa y orquestacion.
- `MapBoard.gd`: presentacion del tablero, scroll y conexion con nodos visuales.
- `LevelNode.gd`: nodo visual clickeable del mapa.
- `MapHud.gd`: HUD del mapa, perfil, racha y boton volver.
- `core/MapNodeData.gd`: dato normalizado del nodo (`order`, `node_key`, `games`, `shuffle_games`).
- `logica/CargadorDeMapa.gd`: carga el mapa, ordena nodos y valida estructura basica.
- `logica/AvanceDeNodo.gd`: consulta progreso, desbloqueo y completado ya guardados.
- `logica/AbridorDeNodoJugable.gd`: abre el nodo jugable actual.
- `logica/ArmadorDePartida.gd`: arma la secuencia de juegos del nodo, resuelve `games` random y aplica `shuffle_games`.
- `logica/ContinuidadDePartidaDeNodo.gd`: avanza al siguiente juego o termina el nodo.

## games

El contrato nuevo usa solo `games` para mantener un formato unico.
`game_slots` queda solo como alias legacy de compatibilidad.

Cada nodo debe usar una sola modalidad:

- `games` fijo: lista de `activity_id`.
- `games` random: lista de objetos con `type` y `difficulty`.

Reglas:

- si un nodo viejo define `games` y `game_slots`, el loader avisa y usa `games`;
- `type` acepta `drag`, `quiz`, `match` y aliases simples (`drag_food`, `vinculacion`);
- `difficulty` usa `1`, `2`, `3`;
- si no hay match exacto para un game random, el armador busca primero dificultad menor y despues mayor;
- si `games` mezcla strings y objetos random, el loader marca error para ese nodo;
- la eleccion random pasa en `ArmadorDePartida.gd`, no en `CargadorDeMapa.gd`.

## shuffle_games

`shuffle_games` solo cambia el orden de ejecucion final dentro del nodo.

Reglas:
- si `games` usa strings, conserva esas mismas actividades y solo cambia el orden;
- si `games` usa objetos random, primero se eligen las actividades y despues se mezcla el resultado;
- si no existe o es `false`, se usa el orden resuelto por el armador;
- si es `true`, se mezcla una copia de la secuencia final cada vez que se arma la partida;
- si el nodo tiene un solo juego, no se aplica shuffle;
- el array original del JSON nunca se modifica.

Ejemplo fijo:

```json
{
	"node_key": "celiaquia_04_desayuno_y_sello",
	"shuffle_games": true,
	"games": ["drag_desayuno_facil", "quiz_sello_sin_tacc"]
}
```

Ejemplo random:

```json
{
	"node_key": "celiaquia_05_intro_mixta",
	"shuffle_games": true,
	"games": [
		{ "type": "drag", "difficulty": 1 },
		{ "type": "quiz", "difficulty": 1 }
	]
}
```

Explicacion trainee:
Un nodo fijo siempre usa los mismos `activity_id`. Un nodo random primero resuelve un `activity_id` por cada request y recien despues puede mezclar el orden final.

## Deuda tecnica visible

`AvanceDeNodo.gd` hoy no persiste progreso por si mismo: consulta y deriva estado desde `Global`. Se mantiene asi para no abrir una refactorizacion grande del flujo de guardado.

## Que vive en core

`core` debe tener datos o contratos simples compartidos.

Actualmente el archivo importante es:

- `MapNodeData.gd`

## Que vive en logica

`logica` contiene reglas del mapa y de la partida:

- cargar mapa;
- calcular avance;
- abrir nodos;
- armar partidas;
- continuar entre juegos.

## Que archivo abre nodos

`logica/AbridorDeNodoJugable.gd`

## Que archivo arma partidas

`logica/ArmadorDePartida.gd`

---

## Layout automatico de nodos sobre la curva

### El problema que resuelve

Posicionar 30 nodos a mano en el editor es fragil: si el diseno del mapa cambia, hay que mover cada nodo individualmente. En cambio, si los nodos siguen una curva, alcanza con editar la curva y los nodos se reposicionan solos.

### La curva: RutaCeliaquia1

`RutaCeliaquia1` es un `Path2D` dentro de `MapBoard.tscn`, invisible en runtime (`visible = false`). Es una herramienta de layout puro, no un elemento visual del juego.

Tiene **30 puntos**, uno por nodo del mapa. Los puntos estan trazados sobre el camino gris de `mapa.png` (1118x1920 px), siguiendo el recorrido que hace el jugador de abajo hacia arriba.

Para editar la curva en el editor de Godot:
1. Abrir `MapBoard.tscn`.
2. Seleccionar `ScrollContainer > Contenido > RutaCeliaquia1`.
3. Activar `visible = true` temporalmente.
4. Usar la herramienta "Edit Curve" para mover puntos.
5. Volver a `visible = false` antes de guardar.

### Algoritmo: placement_mode = "anchors" (el que usamos)

Cada nodo `i` recibe exactamente `curve.get_point_position(i)`.

```
nodo 0  →  get_point_position(0)   posicion exacta del punto 0 de la curva
nodo 1  →  get_point_position(1)   posicion exacta del punto 1 de la curva
...
nodo 29 →  get_point_position(29)  posicion exacta del punto 29 de la curva
```

El nodo i y el punto i son la misma cosa. Disenar el mapa = colocar los puntos de la curva.

**Por que elegimos este modo:**
La alternativa (`curve`) distribuye los nodos por distancia recorrida usando `sample_baked()`. Eso funciona si la curva es uniforme, pero genera deriva en curvas irregulares: nodos intermedios quedan desplazados respecto a donde el diseniador los coloco. Con `anchors` cada punto es exactamente donde el diseniador dijo.

### Algoritmo: placement_mode = "curve" (disponible como fallback)

Los nodos se distribuyen uniformemente por largo de curva.

```gdscript
var normalized = float(i) / float(count - 1)
var t = lerp(t_start, t_end, normalized)
positions.append(curve.sample_baked(t))
```

`t_start` y `t_end` se calculan con `start_margin` y `end_margin` del JSON.
Util si la curva tiene mas o menos puntos que nodos, o si se quiere distribucion automatica sin preocuparse por la cantidad de puntos.

### Fallback automatico

Si se pide modo `anchors` pero la curva tiene menos puntos que nodos, `MapPathLayout` emite un `push_warning` y cae automaticamente a `sample_baked`. La partida no rompe.

### Flujo completo de codigo

```
celiaquia_mapa.json
  layout.route_id = "RutaCeliaquia1"
  layout.placement_mode = "anchors"
        ↓
MapLayoutConfig          parsea route_id, placement_mode, spacing_factor, margenes
        ↓
MapRouteRegistry         busca el Path2D por nombre dentro del nodo Contenido
        ↓
MapPathLayout            si anchors → get_point_position(i) para cada i
                         si curve  → sample_baked(lerp(t_start, t_end, normalized))
        ↓
MapNodePositionResolver  combina los tres pasos → devuelve Array[Vector2] en espacio Contenido
        ↓
MapBoard                 mueve cada nodo: visual.position = layout_pos[i] − contenedor.position
```

El offset del contenedor es `Vector2(-52, -198)` (posicion de `NodesContainer` relativa a `Contenido`).

### Archivos del modulo

| Archivo | Responsabilidad |
|---|---|
| `layout/MapLayoutConfig.gd` | Parsea el bloque `layout` del JSON |
| `layout/MapRouteRegistry.gd` | Busca el `Path2D` por nombre en el arbol de escena |
| `layout/MapPathLayout.gd` | Unico lugar con matematica de posiciones |
| `layout/MapNodePositionResolver.gd` | Elige modo anchors/curve, llama a MapPathLayout |
| `debug/DebugLayoutOverlay.gd` | Dibuja circulos rojos por posicion calculada (apagado por default) |

### Si quiero cambiar...

| Quiero cambiar... | Voy a... |
|---|---|
| Ruta activa | `celiaquia_mapa.json > layout.route_id` |
| Modo de posicionamiento | `celiaquia_mapa.json > layout.placement_mode` |
| Posicion de un nodo (modo anchors) | punto correspondiente en `RutaCeliaquia1` en `MapBoard.tscn` |
| Distribucion generica (modo curve) | `spacing_factor`, `start_margin`, `end_margin` en el JSON |
| Algoritmo matematico | `layout/MapPathLayout.gd` |
| Debug visual de posiciones | `@export var debug_layout = true` en `MapBoard.gd` |

## Que archivo calcula progreso

`logica/AvanceDeNodo.gd`

## Que NO tocar antes de la demo

- No reescribir `MapScene.gd`.
- No reescribir `MapBoard.gd`.
- No cambiar escenas.
- No cambiar nodos.
- No cambiar senales.
- No cambiar navegacion.
- No tocar `Global`.
- No tocar `SaveManager`.
- No inventar un tercer formato JSON fuera de `games`.
- No mover `MapHud`.
- No convertir layout authored a codigo.

## Tests recomendados

Despues de tocar mapas, correr:

- `plan_de_partida_de_nodo_test.gd`
- `partida_de_nodo_multiple_test.gd`
- `flujo_progresivo_de_nodo_test.gd` si existe
- `vertical_slice_smoke_test.gd`
- cualquier test de contenido o vinculacion relacionado
