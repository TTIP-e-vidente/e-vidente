# Mapas

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

## Ruta oficial de lectura

1. `CargadorDeMapa.gd` lee `res://contenido/mapa/celiaquia_mapa.json`.
2. `MapNodeData.gd` normaliza cada nodo a un dato simple.
3. `ArmadorDePartida.gd` arma la secuencia de `games` del nodo.
4. Si `shuffle_games` es `true`, mezcla una copia de `games`.
5. `AbridorDeNodoJugable.gd` abre el juego actual del plan.
6. `ContinuidadDePartidaDeNodo.gd` pasa al siguiente juego o cierra el nodo.
7. `AvanceDeNodo.gd` consulta si el nodo ya estaba desbloqueado o completado.

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
- `logica/ArmadorDePartida.gd`: arma la secuencia de juegos del nodo y aplica `shuffle_games`.
- `logica/ContinuidadDePartidaDeNodo.gd`: avanza al siguiente juego o termina el nodo.

## shuffle_games

`shuffle_games` solo cambia el orden de ejecucion de `games` dentro del nodo.

Reglas:
- si no existe o es `false`, `games` se juega en el orden escrito;
- si es `true`, se mezcla una copia de `games` cada vez que se arma la partida;
- si el nodo tiene un solo juego, no se aplica shuffle;
- el array original del JSON nunca se modifica.

Ejemplo:

```json
{
	"node_key": "celiaquia_05_merienda_intro",
	"shuffle_games": true,
	"games": ["drag_merienda_facil", "quiz_cereales_gluten"]
}
```

Este nodo siempre tiene los mismos dos juegos. Lo unico que cambia entre corridas es cual va primero.

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
- No cambiar formato JSON.
- No mover `MapHud`.
- No convertir layout authored a codigo.

## Tests recomendados

Despues de tocar mapas, correr:

- `plan_de_partida_de_nodo_test.gd`
- `partida_de_nodo_multiple_test.gd`
- `flujo_progresivo_de_nodo_test.gd` si existe
- `vertical_slice_smoke_test.gd`
- cualquier test de contenido o vinculacion relacionado
