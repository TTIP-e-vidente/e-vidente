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
    "action": "Prepará",
    "meal": "un desayuno sin TACC",
    "connector": "para tu amigue",
    "restriction": "celíace"
  }
}
```

### Campos del objetivo drag

| Campo | Obligatorio | Fallback si falta |
|---|---|---|
| `action` | No | `"Prepará"` |
| `meal` | **Recomendado** | Se infiere del `node_key` / `activity_id` (ej. `"desayuno"` → `"un desayuno sin TACC"`) |
| `connector` | No | `"para tu amigue"` |
| `restriction` | No | `"celíace"` si `track_key == "celiaquia"`, vacío en otros tracks |

**Todos los juegos `type: drag` del mapa de celiaquía ya tienen `objective` explícito.**
Dejarlo explícito evita que la UI muestre solo `"Prepará"` sin contexto.

### Formatos de compatibilidad aceptados

El runtime acepta tres variantes; se recomienda el formato anidado:

**Formato recomendado (anidado):**
```json
{
  "type": "drag",
  "objective": {
    "action": "Prepará",
    "meal": "una colación sin TACC",
    "connector": "para tu amigue",
    "restriction": "celíace"
  }
}
```

**Formato plano (legacy aceptado):**
```json
{
  "type": "drag",
  "objective_action": "Prepará",
  "objective_meal": "una colación sin TACC",
  "objective_connector": "para tu amigue",
  "objective_restriction": "celíace"
}
```

**Formato mensaje (legacy aceptado):**
```json
{
  "type": "drag",
  "objective_label": "Prepará",
  "objective_message": "una colación sin TACC\npara tu amigue"
}
```

### Flujo de datos (para mantenimiento)

```
celiaquia_mapa.json (game con objective)
  → MapNodeData._copiar_campos_objetivo()       — preserva campos objetivo
  → ArmadorDePartida._copiar_campos_objetivo()  — preserva en plan de partida
  → Global.obtener_juego_actual_de_partida()    — entrega el game al nivel
  → Level._build_drag_objective_data(game)      — normaliza vía ContentSchemaNormalizer
  → objective_updated.emit(data)                — emite {action, meal, connector, restriction}
  → DragObjectiveText.set_objective(data)       — muestra los labels
```

### Dónde tocar cada cosa

| Necesito cambiar... | Archivo a editar |
|---|---|
| Texto del objetivo (meal, restriction) | `celiaquia_mapa.json` |
| Lógica de fallback de meal/restriction | `sistemas/contenido/ContentSchemaNormalizer.gd` |
| Posición, tamaño, fondo visual del banner | `interface/components/DragObjectiveText/DragObjectiveText.tscn` |
| Textos hardcodeados o animación del banner | `interface/components/DragObjectiveText/drag_objective_text.gd` |
| Cuándo mostrar/ocultar el banner | `niveles/nivel_1/Level.gd` |

**El script `drag_objective_text.gd` no lee JSON ni Global.**
**El TSCN controla el layout; el script solo asigna texto y visibilidad.**

### Diseño visual del mensaje de plato

El mensaje se muestra a través del componente **`DragObjectiveText`**:

```
project/interface/components/DragObjectiveText/DragObjectiveText.tscn
```

Es la **única escena que tu compañera de diseño necesita abrir** para cambiar
el aspecto visual del mensaje de plato.

**Estructura del componente:**

```
DragObjectiveText: Control
├── ActionLabel: Label         ← "Prepará"
├── MealLabel: Label           ← "un desayuno sin TACC"  (negrita, foco principal)
├── MealLine: ColorRect        ← separador delgado bajo la comida
├── ConnectorLabel: Label      ← "para tu amigue"
├── RestrictionLabel: Label    ← "celíace"  (se oculta si no hay restricción)
└── RestrictionLine: ColorRect ← separador delgado final (se oculta junto con RestrictionLabel)
```

**Prueba de diseño (workflow para la diseñadora):**

1. Abrir `DragObjectiveText.tscn` en el editor de Godot.
2. Mover `MealLabel` 20 px hacia abajo.
3. Ejecutar el nivel (`Level.tscn`).
4. Verificar que `MealLabel` aparece 20 px más abajo en runtime.
5. Revertir el movimiento.

Si el cambio no se refleja, significa que algún script está pisando posiciones y
hay que reportarlo como bug.

**El script NO sobreescribe `position` ni `size` de ningún label.**
Fuentes, colores y pesos tipográficos son los únicos overrides que aplica en runtime.

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
