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

`MapScene.gd` carga el JSON del mapa usando `CargadorDeMapa.gd`.

`CargadorDeMapa.gd` valida el JSON y crea objetos `MapNodeData`.

`AvanceDeNodo.gd` calcula si cada nodo esta bloqueado, disponible o completado.

`MapScene.gd` pasa esos datos a `MapBoard.gd`.

`MapBoard.gd` configura los nodos visuales `LevelNode.gd`.

Cuando el jugador toca un nodo, `LevelNode.gd` emite `selected`.

`MapBoard.gd` reemite `node_selected`.

`MapScene.gd` abre el nodo usando `AbridorDeNodoJugable.gd`.

`AbridorDeNodoJugable.gd` arma la sesion y delega en `ArmadorDePartida.gd`.

`ArmadorDePartida.gd` construye la lista de juegos del nodo.

`ContinuidadDePartidaDeNodo.gd` decide si abrir el siguiente juego o terminar la partida del nodo.

## Responsabilidades

- `MapScene.gd`: pantalla principal del mapa y orquestacion.
- `MapBoard.gd`: presentacion del tablero, scroll y conexion con nodos visuales.
- `LevelNode.gd`: nodo visual clickeable del mapa.
- `MapHud.gd`: HUD del mapa, perfil, racha y boton volver.
- `core/MapNodeData.gd`: dato puro de un nodo cargado desde JSON.
- `logica/CargadorDeMapa.gd`: carga y validacion del JSON del mapa.
- `logica/AvanceDeNodo.gd`: calculo de progreso, desbloqueo y completado.
- `logica/AbridorDeNodoJugable.gd`: apertura de un nodo jugable.
- `logica/ArmadorDePartida.gd`: armado de la partida de varios juegos por nodo.
- `logica/ContinuidadDePartidaDeNodo.gd`: continuidad entre juegos de una partida.

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
