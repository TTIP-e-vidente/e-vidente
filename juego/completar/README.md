# Completar palabra

Frase con `____` + botones. Respuesta incorrecta: shake y reintento. Termina cuando todos los blanks están bien.

Contenido: `res://contenido/mapa/completar_palabra.json` · Escena: `completar_palabra.tscn` · Loader: `CargadorCompletar.gd`

## JSON

```json
"word_celiaquia_agua_01": {
  "id": "word_celiaquia_agua_01",
  "mode": "completar_palabra",
  "difficulty": 1,
  "prompt": "Tomar ____ ayuda a mantener el cuerpo hidratado.",
  "correct_answers": ["agua"],
  "choices": ["agua", "gaseosa", "cerveza"],
  "order_matters": false,
  "teaching_key": "celiaquia_bebida"
}
```

| Campo | Nota |
|-------|------|
| `mode` | `completar_palabra` |
| `difficulty` | 1, 2 o 3 |
| `prompt` | Un `____` por cada entrada en `correct_answers` |
| `correct_answers` | Orden si `order_matters: true` |
| `choices` | Incluye las correctas + distractores |

Alias viejos: `sentence`→`prompt`, `answers`→`correct_answers`, `options`→`choices`.

Validación al cargar: cantidad de `____` = tamaño de `correct_answers`; cada correcta ∈ `choices`.

## Escena (nodos)

```
VBoxContainer
├── PromptLabel
├── SentenceLabel
├── OptionsContainer   # botones generados en código
└── FeedbackLabel
```

## Agregar desafío

1. Entrada nueva en `completar_palabra.json`.
2. Referenciar el id en `games` del nodo en `celiaquia_mapa.json` (o random `type` equivalente según mapa).
3. Smoke: `vertical_slice_smoke_test.gd` incluye tests de esta modalidad.

Más contexto mapa: [contenido/README.md](../contenido/README.md).
