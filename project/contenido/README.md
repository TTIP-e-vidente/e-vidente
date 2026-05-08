# Contenido — Guía trainee

## Estructura

```
contenido/
├── catalogos/
│   └── items_celiaquia.json   ← catálogo semántico de items (único activo)
│
├── mapa/
│   ├── celiaquia_mapa.json    ← nodos del capítulo (orden + games por nodo)
│   ├── preguntas.json         ← todas las actividades quiz
│   ├── arrastres.json         ← todas las actividades drag_food
│   └── vinculaciones.json     ← todas las actividades match
│
├── backup/
│   ├── arrastre/              ← drag_drop legacy (json_path viejo)
│   ├── preguntas/             ← quiz legacy
│   ├── vinculacion/           ← match legacy
│   └── celiaquia_pack*.json   ← packs anteriores
│
└── README.md                  ← este archivo
```

---

## El .tres y el JSON son cosas distintas

`items_celiaquia.json` **no reemplaza** al `.tres` — lo complementa.

| Qué | Quién lo define |
|-----|----------------|
| Visual del alimento (imagen, sprite) | `res://items/nombre.tres` |
| Nombre visible en el juego | `res://items/nombre.tres` |
| Si es correcto o incorrecto en celiaquía | `items_celiaquia.json` → `categoria` |
| En qué comida puede aparecer | `items_celiaquia.json` → `meal_type` |
| Qué tags tiene (fruta, trigo, etc.) | `items_celiaquia.json` → `tags` |
| Texto educativo al seleccionarlo | `items_celiaquia.json` → `feedback` |

El sistema resuelve el recurso automáticamente:
```
"banana" → res://items/banana.tres
```

Si el archivo tiene guiones en el nombre, se usa el campo `resource`:
```json
"cafe_leche": {
  "resource": "res://items/cafe-leche.tres",
  ...
}
```

---

## Qué archivo tocar para cada tarea

| Quiero hacer... | Qué hago |
|-----------------|---------|
| Agregar un alimento visual al juego | Crear `res://items/nombre.tres` |
| Usarlo en celiaquía | Agregar key en `catalogos/items_celiaquia.json` |
| Marcarlo como correcto | `categoria: "sin_tacc"` |
| Marcarlo como incorrecto | `categoria: "con_gluten"` o `"riesgo"` |
| Decir dónde puede aparecer | `meal_type: [...]` |
| Crear actividad drag_food | `mapa/arrastres.json` con `meal + pick` |
| Crear actividad quiz | `mapa/preguntas.json` |
| Crear actividad match | `mapa/vinculaciones.json` |
| Agregar un nodo al mapa | `mapa/celiaquia_mapa.json` |
| Ver contenido viejo o recuperar algo | `backup/` |

---

## Equivalencia con level_1.tres

| level_1.tres | JSON nuevo | Dónde |
|---|---|---|
| `itemsPositivos` | items con `"categoria": "sin_tacc"` | `items_celiaquia.json` |
| `itemsNegativos` | items con `"categoria": "con_gluten"` o `"riesgo"` | `items_celiaquia.json` |
| `cantidadPositivos` | `pick.correct` | `arrastres.json` |
| `cantidadNegativos` | `pick.incorrect` | `arrastres.json` |
| Pool filtrado por momento | `meal_type` | `items_celiaquia.json` |
| Shuffle por partida | `RandomNumberGenerator` + anti-repetición | `ActivityAdapter.gd` |

Antes el nivel listaba manualmente qué alimentos mostrar. Ahora el sistema filtra dinámicamente: si la actividad pide `meal: "desayuno"`, solo aparecen items que tengan `"desayuno"` en su `meal_type`.

Cada vez que se juega el mismo nodo, el sistema elige una combinación distinta al azar — igual que el shuffle original.

---

## Formato de items_celiaquia.json

```json
{
  "version": 3,
  "id": "items_celiaquia",
  "tipo": "items_catalog",
  "base_path": "res://items/",
  "items": {
    "banana": {
      "categoria": "sin_tacc",
      "meal_type": ["desayuno", "merienda", "colacion"],
      "tags": ["fruta", "natural"],
      "feedback": "La banana es naturalmente libre de gluten."
    }
  }
}
```

**`categoria`** — define si el alimento es correcto o incorrecto en el juego:

| Valor | En el juego |
|-------|------------|
| `sin_tacc` | Correcto |
| `con_gluten` | Incorrecto |
| `riesgo` | Incorrecto (producto sin rotulo o con riesgo de contaminación) |

**`meal_type`** — define cuándo puede aparecer:

```
desayuno  merienda  colacion  almuerzo  cena  bebida  cocina_segura
```

Un alimento no declarado en `"desayuno"` nunca aparece en un drag_food de desayuno.

**`resource`** — solo si el id JSON no coincide con el nombre del archivo .tres (cuando el archivo tiene guiones):

```json
"cafe_leche": {
  "resource": "res://items/cafe-leche.tres",
  "categoria": "sin_tacc",
  "meal_type": ["desayuno", "merienda", "bebida"]
}
```

---

## Cómo crear una actividad drag_food

Abrí `mapa/arrastres.json`. El arrastre solo declara `meal` y `pick`. No lista alimentos.

```json
"drag_desayuno_facil": {
  "mode": "drag_food",
  "difficulty": 1,
  "prompt": "Arma un desayuno apto sin TACC.",
  "target": "Desayuno apto",
  "meal": "desayuno",
  "pick": { "correct": 2, "incorrect": 1 }
}
```

El runtime busca automáticamente en `items_celiaquia.json` todos los items con `"desayuno"` en su `meal_type`, separa correctos de incorrectos, hace shuffle y selecciona.

| difficulty | pick recomendado |
|-----------|-----------------|
| 1 (fácil) | correct: 2, incorrect: 1 |
| 2 (normal) | correct: 3, incorrect: 2 |
| 3 (difícil) | correct: 3, incorrect: 3 |

---

## Cómo crear una actividad quiz

Abrí `mapa/preguntas.json`:

```json
"quiz_gluten_arroz": {
  "mode": "quiz",
  "difficulty": 2,
  "prompt": "El gluten esta en el arroz?",
  "options": ["No", "Si"],
  "answer": "No"
}
```

---

## Cómo crear una actividad match

Abrí `mapa/vinculaciones.json`:

```json
"match_alimentos": {
  "mode": "match",
  "difficulty": 2,
  "prompt": "Uni cada alimento con su clasificacion.",
  "pairs": [
    ["Banana", "Fruta apta"],
    ["Pan", "Contiene gluten"]
  ]
}
```

---

## Cómo agregar un nodo al mapa

Un nodo es un capítulo. `games` es la lista ordenada de activity_ids que se juegan en ese nodo.

Abrí `mapa/celiaquia_mapa.json` y agregá la siguiente clave numérica dentro de `"nodes"`:

```json
"13": {
  "node_key": "celiaquia_13_nombre_descriptivo",
  "games": ["drag_desayuno_facil", "quiz_gluten_natural"]
}
```

Reglas:
- `node_key` debe ser único en todo el mapa.
- `games` no puede estar vacío.
- Cada activity_id en `games` debe existir en `preguntas.json`, `arrastres.json` o `vinculaciones.json`.
- **No usar `label`** — el mapa v2 no lo incluye.
- `games` puede tener 1, 2 o 3 actividades. La dificultad escala por combinación.

---

## Cómo funciona el mapa

`celiaquia_mapa.json` define los nodos del capitulo.

Cada nodo usa este modelo simple:

- `node_key`: identifica el nodo.
- `games`: lista de juegos del nodo.
- `shuffle_games`: opcional; mezcla el orden de `games`.

Ejemplo:

```json
{
  "node_key": "celiaquia_05_merienda_intro",
  "shuffle_games": true,
  "games": ["drag_merienda_facil", "quiz_cereales_gluten"]
}
```

Explicacion:
Este nodo tiene dos juegos. Cada vez que se arma la partida puede empezar por cualquiera de los dos, pero sigue teniendo exactamente los mismos juegos.

Reglas de `shuffle_games`:

- ausente o `false`: se usa el orden escrito en `games`;
- `true`: se mezcla una copia de `games` cada vez que se entra al nodo;
- si `games.size() <= 1`, no se mezcla nada;
- el JSON original no se modifica.

Flujo trainee:

1. `CargadorDeMapa.gd` lee `celiaquia_mapa.json`.
2. `MapNodeData.gd` guarda `order`, `node_key`, `games` y `shuffle_games`.
3. `ArmadorDePartida.gd` arma la secuencia del nodo.
4. `AbridorDeNodoJugable.gd` abre el juego actual.
5. `ContinuidadDePartidaDeNodo.gd` pasa al siguiente juego.
6. `AvanceDeNodo.gd` consulta si el nodo ya quedo completado.

---

## Flujo completo

```
mapa/celiaquia_mapa.json
  → ArmadorDePartida
    → NodeContentLoader
        carga preguntas.json + arrastres.json + vinculaciones.json
        arma activity_by_id internamente
      → ActivityAdapter (para drag_food)
          lee items_celiaquia.json
          filtra por meal_type + categoria
          resuelve base_path + item_id + ".tres"
          → escena drag_drop / quiz / vinculacion
```

---

## Logs en Godot

```
[ContentPack] mapa cargado id=celiaquia activities=11
[Catalog] items_celiaquia count=85
[DragFood] activity=drag_desayuno_facil meal=desayuno correct=2 incorrect=1
[DragFood] candidates correct=18 incorrect=7
[DragFood] selected=banana,arandano,medialuna
```

---

## backup/

Contiene JSON legacy del sistema anterior (json_path) y packs anteriores. No se cargan como flujo principal. Son respaldo por si hay que recuperar contenido.

No borrar definitivo.
