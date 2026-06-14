# e-vidente

porque el juego es sobre cosas evidentes, o que así deberían serlo.
y porque podés ver el futuro, como un vidente. 

si lo tengo que explicar pierde la gracia verdad...?

Estado: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md) · JSON: [contenido/README.md](contenido/README.md) · Mapa: [mapas/README.md](mapas/README.md) · Vincular: [vincular/README.md](vincular/README.md)

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

- `res://contenido/mapa/celiaquia_mapa.json` define los nodos (ver [contenido/README.md](contenido/README.md)).
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

## Godot: warnings comunes al clonar

### `invalid UID` en escenas (.tscn)

Las escenas referencian UIDs que viven en los `.import` de cada textura/fuente. Si esos `.import` no están en git, cada máquina genera UIDs distintos y Godot avisa (pero igual carga por path).

**Fix de equipo:** versionar `juego/assets-sistema/**/*.import` y `juego/fonts/**/*.import` (ya permitidos en `.gitignore`). Tras clonar:

1. Abrí el proyecto en Godot 4.6 una vez (reimporta lo que falte).
2. Commiteá los `.import` nuevos o actualizados junto con assets nuevos.

**Fix local rápido:** en el editor, `Proyecto → Recargar proyecto actual`.

### Íconos de guardar en Level

Los SVG están en `assets-sistema/interfaz/icono-guardar*.svg`. Si no importaron aún, `Level.gd` usa fallback PNG (`logro-sin-realizar` / `logro-realizado`).

### `WASAPI: GetBufferSize error`

Es del driver de audio de Windows (auriculares desconectados, cambio de dispositivo default, etc.). No rompe el juego; probá reconectar el audio o reiniciar Godot. Si persiste, actualizá drivers o cambiá el dispositivo de salida en Windows antes de abrir el juego.
