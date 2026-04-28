# Contenido de Nodos por JSON

Esta página resume cómo funciona hoy el contenido jugable del mapa.

La idea importante es simple: el mapa ya no abre “preguntas” hardcodeadas. Abre nodos jugables. Cada nodo define su modalidad con `mode` y sus datos específicos con `content`.

## Dónde vive el contenido

```text
project/
  niveles/
    nodos/
      celiaquia/
        gluten_maiz.json
        gluten_arroz.json
        armar_plato_sin_tacc.json
      ejemplos/
        ejemplo_quiz_choice.json
        ejemplo_drag_drop.json
        ejemplo_select_option_legacy.json
        ejemplo_title_card_legacy.json
  preguntas/
    pregunta.gd
    pregunta.tscn
    QuestionJsonLoader.gd
  mapas/
    MapScene.gd
    PlayableNodeRouter.gd
    drag_drop/
      DragDropNode.gd
      DragDropNode.tscn
      DragDropItem.gd
      DragDropTarget.gd
      DragDropValidator.gd
```

- `niveles/nodos/` guarda los JSON de nodos jugables.
- `preguntas/` contiene solo la modalidad `quiz_choice` y su adaptador temporal.
- `mapas/` contiene el mapa, el contexto de apertura y el routing.
- `mapas/drag_drop/` contiene la modalidad `drag_drop`.

## Cómo se lee un nodo

El flujo completo es este:

1. El jugador toca un nodo del mapa.
2. `MapScene.gd` recibe la selección y arma `contexto_sesion`.
3. `NodeContentLoader.gd` carga y normaliza el JSON.
4. `PlayableNodeRouter.gd` mira `mode` y decide qué escena abrir.
5. La escena jugable recibe `node_data`, usa `content` y ejecuta la actividad.
6. Cuando termina, vuelve a `return_scene_path`.

Si querés explicarlo rápido a alguien nuevo, alcanza con esta frase:

“Mapa abre nodo jugable. Loader carga JSON. Router elige escena según `mode`. Escena usa `content`. Escena vuelve al mapa.”

## Convención de rutas

La convención principal hoy es:

- con `track_key = "celiaquia"`
- y `node_key = "gluten_maiz"`

el runtime resuelve:

`res://niveles/nodos/celiaquia/gluten_maiz.json`

Además:

- `node_json_path` y `node_resource_path` son la API principal para casos especiales.
- `question_key`, `question_json_path` y `question_resource_path` quedan solo como compatibilidad legacy interna de escenas viejas. No son la API nueva.
- si llega una ruta vieja de `res://preguntas/json_nodos/`, el loader intenta migrarla y deja una advertencia controlada.

## Contrato oficial del loader

`NodeContentLoader.gd` siempre devuelve esta estructura:

```json
{
  "ok": true,
  "data": {
    "id": "gluten_maiz",
    "theme": "celiaquia",
    "title": "Gluten en el maiz",
    "difficulty": "easy",
    "mode": "quiz_choice",
    "content": {}
  },
  "error": ""
}
```

Después del loader, el runtime debería trabajar solo con `data` ya normalizado.

## Formato JSON oficial

Todos los nodos jugables comparten estos campos:

```json
{
  "id": "gluten_maiz",
  "theme": "celiaquia",
  "title": "Gluten en el maiz",
  "difficulty": "easy",
  "mode": "quiz_choice",
  "content": {}
}
```

La lectura correcta es:

- `mode` define la modalidad.
- `content` contiene solo los datos específicos de esa modalidad.

### Ejemplo de `quiz_choice`

```json
{
  "id": "gluten_maiz",
  "theme": "celiaquia",
  "title": "Gluten en el maiz",
  "difficulty": "easy",
  "mode": "quiz_choice",
  "content": {
    "question": "El maiz contiene gluten?",
    "correct_answer": "No",
    "wrong_options": ["Si", "Solo si esta cocido", "Depende del color"],
    "visual_resource": ""
  }
}
```

### Ejemplo de `drag_drop`

```json
{
  "id": "armar_plato_sin_tacc",
  "theme": "celiaquia",
  "title": "Arma un plato apto",
  "difficulty": "easy",
  "mode": "drag_drop",
  "content": {
    "instruction": "Arrastra al plato solo los alimentos aptos sin TACC.",
    "targets": [
      {
        "id": "plato",
        "label": "Plato apto"
      }
    ],
    "items": [
      {
        "id": "arroz",
        "label": "Arroz",
        "image": "res://assets-sistema/iconos/arroz-0.png",
        "correct_target": "plato"
      },
      {
        "id": "pan",
        "label": "Pan",
        "image": "res://assets-sistema/iconos/pan-0.png",
        "correct_target": ""
      }
    ],
    "success_message": "Bien! Elegiste alimentos aptos.",
    "error_message": "Cuidado: ese alimento puede contener gluten."
  }
}
```

## Qué pide cada modalidad

- `quiz_choice` requiere `question`, `correct_answer` y `wrong_options`.
- `drag_drop` requiere `instruction`, `targets` e `items`.

Si querés ver dónde se valida eso, el punto canónico es `project/preguntas/NodeContentValidator.gd`.

## Compatibilidad legacy que sigue viva

Todavía quedan algunas compatibilidades controladas para no romper contenido viejo:

- `select_option` se normaliza a `quiz_choice`.
- `drag_to_target` se normaliza a `drag_drop`.
- `QuestionJsonLoader.gd` adapta solo `quiz_choice` al modelo viejo `ThemePreg/Preguntas`.
- el fallback `.tres` sigue disponible para nodos legacy.

## Cómo crear un nodo nuevo

1. Elegí `track_key` y `node_key`, por ejemplo `celiaquia` + `mito_gluten`.
2. Creá `project/niveles/nodos/celiaquia/mito_gluten.json`.
3. Pegá el formato oficial con el `mode` correcto.
4. En el nodo del mapa, configurá `node_key = "mito_gluten"`.
5. Probá el flujo completo desde el mapa.

## Cómo agregar una modalidad futura

1. Agregar el nuevo `mode` en `NodeContentLoader.gd`.
2. Validar su `content` mínimo en `NodeContentValidator.gd`.
3. Agregar su ruta en `PlayableNodeRouter.gd`.
4. Crear la escena jugable que lea `node_data` desde la sesión.
5. Resolver su finalización con `return_scene_path` para volver al mapa.

## Checklist manual

- Abrir un nodo `quiz_choice` desde el mapa.
- Responder el quiz y verificar que vuelve.
- Abrir un nodo `drag_drop` desde el mapa.
- Completar `drag_drop` y verificar que vuelve.
- Probar un `mode` inválido y verificar error controlado.
- Probar contenido faltante y verificar error claro.
- Probar un JSON legacy `select_option` y verificar normalización a `quiz_choice`.
- Probar una ruta vieja `res://preguntas/json_nodos/...` y verificar migración.
- Crear un nodo nuevo en `project/niveles/nodos/<track_key>/` y abrirlo desde el mapa.
