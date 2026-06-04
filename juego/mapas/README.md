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

### Convencion de escena (una sola fuente de verdad)

Todas las rutas viven en:

`MapBoard.tscn > ScrollContainer > Contenido > NodesContainer > Rutas > <route_id>`

Ejemplo: `Rutas/RutaCeliaquia1` es un `Path2D` invisible en runtime. Los puntos de la curva usan **las mismas coordenadas** que los nodos visuales (`Receta1`, `Pregunta1`, etc.): no hay conversion ni rutas duplicadas bajo `Contenido`.

Para editar posiciones en modo `anchors`:
1. Abrir `MapBoard.tscn`.
2. Ir a `NodesContainer > Rutas > RutaCeliaquia1` (o la ruta activa del JSON).
3. `visible = true` en la ruta mientras editas.
4. Herramienta "Edit Curve": punto `i` = nodo con `nivel_id = i + 1`.
5. `visible = false` antes de guardar.
6. Opcional: `debug_layout = true` en `MapBoard` para ver circulos rojos con indices.

### JSON del mapa (`layout`)

```json
"layout": {
  "route_id": "RutaCeliaquia1",
  "placement_mode": "anchors",
  "start_margin": 0.0,
  "end_margin": 0.0
}
```

| Campo | Uso |
|---|---|
| `route_id` | Nombre del `Path2D` dentro de `NodesContainer/Rutas/` |
| `placement_mode` | `"anchors"` (1 punto = 1 nodo) o `"curve"` (reparto por largo) |
| `start_margin` / `end_margin` | Solo en modo `curve` |

### Escalar a otro mapa o capitulo

1. Duplicar un `Path2D` en `NodesContainer/Rutas/` (ej. `RutaVegana1`).
2. Trazar la curva con un punto por nodo del JSON.
3. En el JSON del mapa, apuntar `layout.route_id` a ese nombre.
4. Instanciar nodos en `NodesContainer` con `nivel_id` 1..N en orden.

### Flujo de codigo

```
celiaquia_mapa.json → layout.route_id + placement_mode
        ↓
MapLayoutConfig
        ↓
MapRouteRegistry → NodesContainer/Rutas/<route_id>
        ↓
MapPathLayout.resolve → anchors | curve
        ↓
MapBoard → visual.position = posiciones[i]
```

### Archivos del modulo

| Archivo | Responsabilidad |
|---|---|
| `layout/MapLayoutConfig.gd` | Parsea `layout` del JSON |
| `layout/MapRouteRegistry.gd` | Busca `Rutas/<route_id>` |
| `layout/MapPathLayout.gd` | `resolve()`, `calcular_por_anchors()`, `calcular_por_curva()` |
| `debug/DebugLayoutOverlay.gd` | Debug visual (solo con `debug_layout`) |

### Referencia rapida

| Quiero... | Donde |
|---|---|
| Cambiar ruta activa | JSON `layout.route_id` |
| Mover un nodo (anchors) | Punto `i` en `Rutas/<route_id>` |
| Reparto automatico sin 1:1 | JSON `placement_mode: "curve"` + margenes |
| Ver alineacion | `MapBoard.debug_layout = true` |

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
