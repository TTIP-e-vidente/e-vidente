# Flujo de contenido JSON

## Donde vive cada cosa

- Mapa:
  `res://contenido/mapas/celiaquia_mapa.json`
- Preguntas:
  `res://contenido/nodos/celiaquia/preguntas/`
- Arrastre:
  `res://contenido/nodos/celiaquia/arrastre/`

## Como crear una pregunta nueva

1. Copiar un JSON existente de `preguntas/`.
2. Cambiar `id`, `title`, `difficulty` y `content`.
3. Guardarlo en `res://contenido/nodos/celiaquia/preguntas/`.
4. Agregarlo a `celiaquia_mapa.json` con `node_key`, `title`, `mode: "quiz_choice"` y `json_path`.
5. Validar que el `json_path` exista y que `wrong_options` no repita `correct_answer`.

Ejemplo de entrada en el mapa:

```json
{
  "node_key": "etiquetas_sin_tacc",
  "title": "Etiquetas sin TACC",
  "mode": "quiz_choice",
  "json_path": "res://contenido/nodos/celiaquia/preguntas/etiquetas_sin_tacc.json"
}
```

## Como crear un nivel de arrastre nuevo

1. Copiar un JSON existente de `arrastre/`.
2. Cambiar `id`, `title`, `difficulty` y `content`.
3. Guardarlo en `res://contenido/nodos/celiaquia/arrastre/`.
4. Agregarlo al mapa con `node_key`, `title`, `mode: "drag_drop"` y `json_path`.
5. Validar que `targets` e `items` tengan `id` unico y que al menos un item tenga `correct_target` valido.

## Contrato minimo del mapa

Cada entrada de `nodes` debe tener:

- `node_key`: clave unica del nodo.
- `title`: texto visible en el mapa.
- `mode`: `quiz_choice` o `drag_drop`.
- `json_path`: ruta al JSON de la leccion.

## Flujo en runtime

`celiaquia_mapa.json`
-> `MapJsonLoader`
-> `MapNodeData`
-> `MapBoard`
-> `PlayableNodeRouter`
-> `Level` o `pregunta`
-> `PostGameFlowController`
-> mapa

## Sesion jugable nueva

El camino feliz usa solo estas claves:

- `node_key`
- `node_title`
- `mode`
- `json_path`
- `track_key`
- `return_to`
- `level_number`

## Compatibilidad legacy

- `NodeContentLegacy.gd` es el unico adaptador para rutas o shapes viejos.
- El flujo nuevo no deberia usar `res://niveles/nodos/` ni `res://niveles/mapas/`.
- Alias como `node_json_path`, `node_resource_path`, `node_mode`, `nivel_id` y `return_scene_path` siguen aceptados solo para no romper contenido o sesiones viejas.

## Validacion rapida cuando haya Godot CLI

```bash
godot --headless --path project -s res://tests/map_progress_visual_test.gd
```