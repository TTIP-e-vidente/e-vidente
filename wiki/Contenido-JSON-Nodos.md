# Contenido JSON de nodos

Guia breve para editar contenido sin conocer todo el runtime.

## Mapa

El mapa activo esta en `project/contenido/mapa/celiaquia_mapa.json`.
Cada nodo define una lista `games`. Para trainees, usar objetos claros:

```json
{
  "type": "drag",
  "difficulty": 1,
  "objective": {
    "action": "Prepara",
    "meal": "un desayuno sin TACC",
    "connector": "para tu amigue",
    "restriction": "celiace"
  }
}
```

Compatibilidad: siguen funcionando `objective_label`, `objective_message`,
`objective_action`, `objective_meal`, `objective_connector` y
`objective_restriction`, pero el runtime normaliza todo a `objective`.

Si falta `objective`, el normalizador genera un fallback simple usando
`node_key`, `activity_id` o `teaching_key`. Aun asi, el mapa de celiaquia deja
objetivos explicitos para evitar que la UI muestre solo "Prepara".

## Completar Palabra

El contenido activo esta en `project/contenido/mapa/completar_palabra.json`.
Se mantiene el diccionario por id para que el diff sea estable:

```json
{
  "word_celiaquia_tacc_01": {
    "id": "word_celiaquia_tacc_01",
    "mode": "completar_palabra",
    "difficulty": 1,
    "prompt": "Los productos sin TACC estan libres de ____.",
    "correct_answers": ["gluten"],
    "choices": ["gluten", "azucar", "sal"],
    "order_matters": false,
    "teaching_key": "celiaquia_desayuno"
  }
}
```

Compatibilidad obligatoria:

| Formato anterior | Formato trainee |
|---|---|
| `sentence` | `prompt` |
| `answers` | `correct_answers` |
| `options` | `choices` |

El loader acepta ambos formatos y entrega ambos aliases al minijuego para no
romper escenas o tests viejos.

## Preguntas

`project/contenido/mapa/preguntas.json` ya usa nombres bastante claros:
`prompt`, `options` y `answer`.

Aliases recomendados para futuro, sin migracion masiva por ahora:

| Actual | Alias trainee posible |
|---|---|
| `prompt` | `question_text` |
| `answer` | `correct_answer` |
| `options` | `choices` |

## Arrastres

`project/contenido/mapa/arrastres.json` describe actividades `drag_food` por
`meal`, `difficulty`, `teaching_key` y `pick`. No lista alimentos: el runtime
los toma desde el catalogo de items.

Convencion de ids recomendada:

```text
drag_<meal>_<dificultad>
```

Ejemplos: `drag_desayuno_facil`, `drag_cena_dificil`.

## Flujo normalizado

1. `CargadorDeMapa.gd` lee el mapa.
2. `MapNodeData.gd` conserva `games`.
3. `ArmadorDePartida.gd` arma el plan y normaliza `objective`.
4. `Global` expone el juego actual ya enriquecido.
5. `Level.gd` envia a `DragObjectiveText` solo `action`, `meal`, `connector` y `restriction`.
6. `CargadorCompletar.gd` normaliza completar palabra desde formato viejo o trainee.
