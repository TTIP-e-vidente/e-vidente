# Contenido JSON

La regla oficial para contenido nuevo es esta: 1 JSON = 1 nodo jugable.

Tipos permitidos para contenido nuevo:

- `arrastre`
- `preguntas`
- `vinculacion`

Guardá cada archivo en su carpeta por tipo:

- `res://contenido/nodos/celiaquia/arrastre/`
- `res://contenido/nodos/celiaquia/preguntas/`
- `res://contenido/nodos/celiaquia/vinculacion/`

El único archivo que hoy queda en la raíz es `receta_1_desayuno.json` por compatibilidad con el primer nodo del mapa.

## Formato actual

Hoy conviven dos formatos activos en el proyecto:

- `arrastre` y `preguntas` usan el formato actual de archivos del juego: `theme`, `title`, `difficulty`, `mode` y `content`.
- `vinculacion` sigue usando el formato simple con `tipo`, `titulo`, `dificultad`, `consigna`, `ensenanza` y `pares`.

No mezcles ambos formatos dentro del mismo archivo.

## Cómo crear arrastre

1. Copiá `res://contenido/plantillas/arrastre.json`.
2. Cambiá `id`, `title`, `difficulty`, `content.teaching_key` y `content.instruction`.
3. En `targets`, definí el destino correcto del plato.
4. En `items`, cargá `id`, `label`, `image` y `correct_target`.

## Cómo crear pregunta

1. Copiá `res://contenido/plantillas/preguntas.json`.
2. Cambiá `id`, `title`, `difficulty` y `content.question`.
3. Definí `content.correct_answer` y `content.wrong_options`.
4. Si hace falta, usá `content.visual_resource` para una imagen asociada.

Ejemplo mínimo:

```json
{
  "id": "eliminar_gluten",
  "theme": "celiaquia",
  "title": "Eliminar gluten del trigo",
  "difficulty": "easy",
  "mode": "quiz_choice",
  "content": {
    "question": "Eliminar el gluten visible de una comida con trigo no evita la contaminación.",
    "correct_answer": "Verdadero",
    "wrong_options": ["Falso"],
    "visual_resource": ""
  }
}
```

Ejemplo mínimo de arrastre:

```json
{
  "id": "receta_2_colacion",
  "theme": "celiaquia",
  "title": "Arma una colacion segura",
  "difficulty": "easy",
  "mode": "drag_drop",
  "content": {
    "teaching_key": "celiaquia_2",
    "instruction": "Arrastra solo las colaciones aptas sin TACC.",
    "targets": [
      {
        "id": "colacion",
        "label": "Colacion apta"
      }
    ],
    "items": [
      {
        "id": "manzana",
        "label": "Manzana",
        "image": "res://assets-sistema/iconos/manzana-0.png",
        "correct_target": "colacion"
      },
      {
        "id": "barra_cereal_sin_rotulo",
        "label": "Barra de cereal sin rotulo",
        "image": "res://assets-sistema/iconos/barra-cereal-0.png",
        "correct_target": ""
      }
    ]
  }
}
```

## Cómo crear vinculación

1. Copiá `res://contenido/plantillas/vinculacion.json`.
2. Cambiá `id`, `titulo`, `dificultad`, `consigna` y `ensenanza`.
3. Escribí `pares` con `izquierda`, `derecha` y `explicacion`.
4. Si querés sumar ruido controlado, agregá `distractores`.

Ejemplo mínimo:

```json
{
  "id": "vincular_alimentos_seguridad",
  "tipo": "vinculacion",
  "titulo": "Vincula alimentos seguros",
  "dificultad": "medium",
  "consigna": "Uní cada alimento con su clasificación.",
  "ensenanza": "celiaquia_2",
  "pares": [
    {
      "izquierda": "Banana",
      "derecha": "Fruta apta",
      "explicacion": "La banana es naturalmente libre de gluten."
    },
    {
      "izquierda": "Pan",
      "derecha": "Harina de trigo",
      "explicacion": "El pan común contiene gluten."
    }
  ],
  "distractores": ["Solo bebida"]
}
```

## Cómo elegir dificultad

- `easy`: conceptos directos, una decisión evidente, una pregunta por archivo si querés probar rápido.
- `medium`: distinguir etiquetas, contaminación cruzada o contexto de cocina.
- `hard`: casos cotidianos, hábitos seguros y decisiones de diagnóstico.

## Cómo agregarlo al mapa

Usá entradas explícitas en `res://contenido/mapas/celiaquia_mapa.json`:

```json
{
  "node_key": "eliminar_gluten",
  "title": "Eliminar gluten del trigo",
  "mode": "quiz_choice",
  "difficulty": 1,
  "json_path": "res://contenido/nodos/celiaquia/preguntas/eliminar_gluten.json"
}
```

Para vinculación:

```json
{
  "node_key": "vincular_conceptos",
  "title": "Vincula Conceptos",
  "mode": "vinculacion_conceptos",
  "difficulty": 3,
  "json_path": "res://contenido/nodos/celiaquia/vinculacion/vincular_conceptos.json"
}
```

Para arrastre:

```json
{
  "node_key": "receta_2_colacion",
  "title": "Arma una colación segura",
  "mode": "drag_drop",
  "difficulty": 1,
  "json_path": "res://contenido/nodos/celiaquia/arrastre/receta_2_colacion.json"
}
```

No mezcles ejemplos de prueba en la carpeta productiva. Si necesitás samples para tests, dejalos fuera del árbol principal de `contenido/nodos/celiaquia/`.

## Qué no mezclar

No combines formatos dentro del mismo archivo:

- en `preguntas`, no mezcles `question/correct_answer/wrong_options` con `preguntas[].texto/opciones/respuesta`
- en `arrastre`, no mezcles `targets/items` con `correctos/incorrectos`
- en `vinculacion`, mantené `pares` y `distractores` como está hoy en `contenido/nodos/celiaquia/vinculacion/`

## Compatibilidad y legacy

Se mantiene compatibilidad con contenido anterior:

- si un archivo tiene `juegos`, sigue funcionando el flujo multi-juego V1
- si un archivo no tiene `juegos`, se trata como actividad jugable directa
- los arrastres y nodos legacy ya existentes siguen funcionando

No copies archivos legacy como base para contenido nuevo.

## Validación recomendada

```bash
godot --headless --path project -s res://tests/vincular_conceptos_scene_test.gd
```
