# Contenido (celiaquía)

## Carpetas

```
contenido/
├── catalogos/items_celiaquia.json
├── mapa/
│   ├── celiaquia_mapa.json      # nodos + games
│   ├── preguntas.json           # quiz
│   ├── arrastres.json           # drag_food
│   ├── vinculaciones.json       # match
│   └── completar_palabra.json
└── backup/                      # legacy, no cargar contenido nuevo acá
```

## Flujo

`celiaquia_mapa.json` → `ArmadorDePartida` → `NodeContentLoader` → `ActivityAdapter` → minijuego → `ContinuidadDePartidaDeNodo`.

`games`: ids fijos (`"drag_desayuno_facil"`) o random (`{ "type": "drag", "difficulty": 2 }`). `shuffle_games` solo mezcla el orden final.

## .tres vs JSON

| Dato | Archivo |
|------|---------|
| Sprite, nombre visible | `res://items/*.tres` |
| Correcto/incorrecto celiaquía | `items_celiaquia.json` → `categoria` |
| Cuándo aparece | `meal_type` |
| Texto al tocar | `feedback` |

`"banana"` → `res://items/banana.tres`. Si el archivo tiene guiones: `"resource": "res://items/cafe-leche.tres"`.

**Categorías:** `sin_tacc` (ok) · `con_gluten` / `riesgo` (mal).  
**Meals:** `desayuno`, `merienda`, `colacion`, `almuerzo`, `cena`, `bebida`, `cocina_segura`.

## Tareas rápidas

| Tarea | Archivo |
|-------|---------|
| Nuevo alimento | `.tres` + entrada en `items_celiaquia.json` |
| Drag | `arrastres.json` |
| Quiz | `preguntas.json` |
| Match | `vinculaciones.json` |
| Completar palabra | `completar_palabra.json` |
| Nodo en mapa | `celiaquia_mapa.json` |

## items_celiaquia.json (mínimo)

```json
"banana": {
  "categoria": "sin_tacc",
  "meal_type": ["desayuno", "merienda"],
  "tags": ["fruta"],
  "feedback": "..."
}
```

## Activities

**Drag** (`arrastres.json`) — solo `meal` + `pick`; el runtime filtra items del catálogo:

```json
"drag_desayuno_facil": {
  "mode": "drag_food",
  "difficulty": 1,
  "meal": "desayuno",
  "teaching_key": "celiaquia_desayuno",
  "pick": { "correct": 2, "incorrect": 1 }
}
```

Pick orientativo: diff 1 → 2+1, diff 2 → 3+2, diff 3 → 3+3.

**Quiz:**

```json
"quiz_gluten_arroz": {
  "mode": "quiz",
  "difficulty": 2,
  "prompt": "¿El gluten está en el arroz?",
  "options": ["No", "Sí"],
  "answer": "No"
}
```

**Match:** `pairs` en `vinculaciones.json`.

**Completar palabra:** `prompt`, `correct_answers`, `choices`, `order_matters`. Alias viejos: `sentence`/`answers`/`options`.

## Nodos (`celiaquia_mapa.json`)

```json
"13": {
  "node_key": "celiaquia_13_ejemplo",
  "games": ["drag_desayuno_facil", "quiz_gluten_arroz"]
}
```

Random:

```json
"14": {
  "node_key": "celiaquia_14_mix",
  "shuffle_games": true,
  "games": [
    { "type": "drag", "difficulty": 2, "objective": {
      "action": "Prepara", "meal": "un desayuno sin TACC",
      "connector": "para tu amigue", "restriction": "celiace"
    }},
    { "type": "quiz", "difficulty": 1 }
  ]
}
```

Reglas:
- `node_key` único; `games` no vacío.
- Cada id fijo debe existir en preguntas/arrastres/vinculaciones/completar.
- Random: `type` (`drag`|`quiz`|`match`) + `difficulty` 1–3; resolución exacta → menor → mayor.
- No mezclar strings y objetos en el mismo `games`.
- Sin `label` (mapa v2). `game_slots` = alias legacy.

`objective` en drag evita UI genérica; también acepta campos legacy `objective_*` (normalizados en runtime).

## Equivalencia level_1.tres

| .tres | JSON |
|-------|------|
| itemsPositivos/Negativos | `categoria` en catálogo |
| cantidadPositivos/Negativos | `pick.correct` / `pick.incorrect` |
| pool por momento | `meal_type` |

## Logs útiles

```
[ContentPack] mapa cargado ...
[Catalog] items_celiaquia count=...
[DragFood] activity=... meal=... selected=...
```

## backup/

Solo recuperación. No agregar contenido nuevo ahí.
