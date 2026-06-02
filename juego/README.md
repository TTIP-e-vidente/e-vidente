# e-vidente

porque el juego es sobre cosas evidentes, o que así deberían serlo.
y porque podés ver el futuro, como un vidente. 

si lo tengo que explicar pierde la gracia verdad...?

## Flujo congelado para demo

El flujo de contenido y mapa queda congelado para demo.

## Como leer el flujo

1. El mapa define nodos.
2. Cada nodo tiene `games`.
3. `games` puede ser fijo o random.
4. `ArmadorDePartida` decide que se juega.
5. `NodeContentLoader` busca la activity.
6. `ActivityAdapter` la adapta.
7. El minijuego se ejecuta.
8. `ContinuidadDePartidaDeNodo` decide si sigue otro game o termino.

- `res://contenido/mapa/celiaquia_mapa.json` define los nodos.
- `games` con strings representan activities fijas.
- `games` con objetos representan requests random por `type` y `difficulty`.
- `shuffle_games` solo mezcla el orden final de los games resueltos.
- `NodeContentLoader` carga activities y candidates.
- `ActivityAdapter` adapta la activity al minijuego runtime.
- no modificar este flujo salvo bug critico.

Ejemplo fijo:

```json
"games": [
	"drag_desayuno_facil",
	"quiz_sello_sin_tacc"
]
```

Ejemplo random:

```json
"games": [
	{ "type": "drag", "difficulty": 2 },
	{ "type": "quiz", "difficulty": 2 },
	{ "type": "match", "difficulty": 2 }
]
```

Notas sobre `shuffle_games`:

- solo mezcla el orden final.
- no elige activities.
- no modifica el JSON original.
