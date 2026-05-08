# Contenido JSON

La regla recomendada para contenido nuevo es esta:

- cada JSON nuevo representa un nodo jugable
- no separar nodo y juego si no hace falta
- no usar pools
- no usar `.tres` dentro del JSON del nodo
- no copiar formatos legacy

## Ruta oficial para crear arrastre nuevo

1. Copiá `res://contenido/plantillas/arrastre.json`
2. Cambiá textos e ids
3. Usá ids humanos definidos en `res://contenido/items.json`
4. Agregá el archivo al mapa

El JSON simple ya es suficiente para jugar.

## Formato oficial de arrastre

Archivo real de referencia: `res://contenido/nodos/celiaquia/arrastre/receta_1_desayuno.json`

Plantilla oficial: `res://contenido/plantillas/arrastre.json`

```json
{
  "id": "desayuno",
  "tipo": "arrastre",
  "titulo": "Prepará el desayuno",
  "consigna": "Arrastrá al plato solo opciones aptas sin TACC.",
  "plato": "Desayuno apto",
  "correctos": ["banana", "leche", "manzana", "pera"],
  "incorrectos": ["medialuna", "pan", "tostado_jyq"],
  "cantidad_correctos": 2,
  "cantidad_incorrectos": 1,
  "ensenanza": "celiaquia_1"
}
```

Conversión automática del runtime:

- `consigna` se convierte a `instruction`
- `plato` crea el `target` automáticamente
- `correctos` e `incorrectos` se resuelven con `res://contenido/items.json`
- `ensenanza` se convierte a `teaching_key`
- el runtime asigna `correct_target` sin que tengas que escribirlo

## Catálogo oficial de items

Usa `res://contenido/items.json`.

Ese archivo resuelve ids humanos como:

- `banana`
- `leche`
- `manzana`
- `tostado_jyq`

Si necesitas un item nuevo, primero agrégalo en `items.json`.

## Cómo agregar el nodo al mapa

Ejemplo mínimo:

```json
{
  "id": "celiaquia",
  "titulo": "Celiaquia",
  "nodos": [
    {
      "id": "receta_1_desayuno",
      "archivo": "res://contenido/nodos/celiaquia/arrastre/receta_1_desayuno.json"
    }
  ]
}
```

Ejemplo real simple: `res://contenido/mapas/celiaquia.json`

## Qué sigue siendo legacy

Estos archivos siguen funcionando, pero no son la forma recomendada para crear contenido nuevo:

- `res://contenido/nodos/celiaquia/arrastre/armar_plato_sin_tacc.json`
- `res://contenido/nodos/celiaquia/arrastre/nuevo_nodo.json`
- `res://contenido/nodos/celiaquia/arrastre/receta_2_colacion.json`
- `res://contenido/nodos/celiaquia/arrastre/receta_3_almuerzo.json`
- y el resto de arrastres/preguntas ya existentes en el mapa demo

No copies esos archivos como base porque usan contratos anteriores mezclados.

## Compatibilidad que se mantiene

- si un archivo tiene `juegos`, sigue funcionando el flujo multi-juego actual
- si un archivo no tiene `juegos`, el loader lo trata como una actividad jugable directa
- `celiaquia_mapa.json` sigue funcionando para la demo actual
- no se tocó avance de nodo

## Validación recomendada

```bash
godot --headless --path project -s res://tests/nodo_jugable_directo_test.gd
godot --headless --path project -s res://tests/contenido_arrastre_nodo_uno_test.gd
godot --headless --path project -s res://tests/partida_de_nodo_multiple_test.gd
```
