# Contenido de Nodos por JSON

Esta guia explica como desacoplar el contenido de nodos del mapa para que la logica de juego sea reutilizable sin hardcodear consignas en scripts.

## Resumen

- Lo mas simple ahora es configurar solo `question_key`.
- El sistema busca automaticamente:
  - `res://preguntas/json_nodos/<question_key>.json`
  - y si no existe o falla, `res://preguntas/preguntas_recurso/<question_key>.tres`
- `question_json_path` y `question_resource_path` siguen existiendo, pero ya son opcionales.
- Asi no se rompen nodos existentes y el authoring queda mucho mas corto.

## Dónde se integra

- Contrato del nodo: `project/mapas/MapNodeData.gd`
- Authoring del nodo: `project/mapas/LevelNode.gd`
- Sesion de mapa -> pregunta: `project/mapas/MapScene.gd`
- Loader JSON: `project/preguntas/QuestionJsonLoader.gd`
- Consumo en escena pregunta: `project/preguntas/pregunta.gd`

## Formato JSON recomendado

Formato recomendado hoy, mas claro para trainees:

```json
{
  "schema_version": 1,
  "node": {
    "node_kind": "question",
    "question_key": "mito_gluten",
    "title": "Pregunta 1",
    "track_key": "celiaquia",
    "question_number": 1,
    "difficulty": "basica",
    "estimated_seconds": 20
  },
  "activity": {
    "type": "quiz_choice",
    "title": "Pregunta 1",
    "instruction": "Lee la consigna y elegi la respuesta correcta."
  },
  "question": {
    "prompt": "Texto de la pregunta",
    "correct_answer": "Verdadero",
    "wrong_answers": ["Falso"],
    "type": "text"
  }
}
```

Tipos de actividad que puede describir el JSON:

- `quiz_choice`
- `select_option`
- `drag_to_target`
- `title_card`

Hoy la escena `pregunta.gd` consume directo `quiz_choice` y `select_option`.

Formato minimo, que tambien sigue funcionando:

```json
{
  "prompt": "Texto de la consigna",
  "correct_answer": "Verdadero",
  "wrong_answers": ["Falso"],
  "type": "text"
}
```

Formato extendido, si queres agrupar metadata:

```json
{
  "schema_version": 1,
  "node": {
    "id": "celiaquia_pregunta_01",
    "title": "Pregunta 1",
    "topic": "celiaquia",
    "difficulty": "facil",
    "modalities": ["quiz_choice"],
    "lessons": [
      {
        "id": "eliminar_gluten",
        "prompt": "Texto de la consigna",
        "correct_answer": "Verdadero",
        "wrong_answers": ["Falso"],
        "type": "text",
        "assets": {
          "image_path": "",
          "audio_path": "",
          "video_path": ""
        }
      }
    ]
  }
}
```

## Campos minimos por leccion

- `prompt`
- `correct_answer`
- `wrong_answers` o `options`

## Aliases soportados

- `consigna` -> `prompt`
- `respuesta_correcta` -> `correct_answer`
- `opciones` -> `options`
- `opciones_incorrectas` -> `wrong_answers`

## Validacion controlada

El sistema informa con `push_warning` cuando:

- no existe el archivo,
- el JSON no parsea,
- faltan campos requeridos,
- o un recurso visual/sonoro no carga.

Si hay error, cae a `.tres` para mantener compatibilidad.

## Flujo trainee-friendly para crear un nodo nuevo

1. Elegir una clave simple, por ejemplo `mito_gluten`.
2. Crear `project/preguntas/json_nodos/mito_gluten.json`.
3. Pegar el formato recomendado:

```json
{
  "schema_version": 1,
  "node": {
    "node_kind": "question",
    "question_key": "mito_gluten",
    "title": "Pregunta nueva",
    "track_key": "celiaquia",
    "question_number": 1,
    "difficulty": "basica",
    "modality": "quiz_choice"
  },
  "question": {
    "prompt": "Tu consigna",
    "correct_answer": "Si",
    "wrong_answers": ["No"],
    "type": "text"
  }
}
```

4. En el nodo del mapa, escribir solo `question_key = "mito_gluten"`.
5. Probar el nodo.

No hace falta escribir rutas si seguis la convencion de nombres.

## Cuando usar rutas explicitas

Usa `question_json_path` o `question_resource_path` solo si:

- queres guardar el archivo en otra carpeta,
- queres migrar de forma gradual,
- o tenes un caso especial que no sigue la convencion.
