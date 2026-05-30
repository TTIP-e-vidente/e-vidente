# Contenido JSON para mensaje en Arrastre


## Mapa

El mapa activo esta en `project/contenido/mapa/celiaquia_mapa.json`.
Cada nodo define una lista `games`.

```json
{
  "type": "drag",
  "difficulty": 1,
  "objective": {
    "action": "Prepará",
    "meal": "un desayuno sin TACC",
    "connector": "para tu amigue",
    "restriction": "con celiaquía"
  }
}
```

### Campos del objetivo drag

| Campo | Obligatorio | Fallback si falta |
|---|---|---|
| `action` | No | `"Prepará"` |
| `meal` | **Recomendado** | Se infiere del `node_key` / `activity_id` (ej. `"desayuno"` → `"un desayuno sin TACC"`) |
| `connector` | No | `"para tu amigue"` |
| `restriction` | No | `"celiaquía"` si `track_key == "celiaquia"`, vacío en otros tracks |

**Todos los juegos `type: drag` del mapa de celiaquía ya tienen `objective` explícito.**
Dejarlo explícito evita que la UI muestre solo `"Prepará"` sin contexto.

### Formatos de compatibilidad aceptados

El runtime acepta tres variantes; se recomienda el formato anidado:

**Formato recomendado:**
```json
{
  "type": "drag",
  "objective": {
    "action": "Prepará",
    "meal": "una colación sin TACC",
    "connector": "para tu amigue",
    "restriction": "con celiaquía"
  }
}
```

**Formato plano:**
```json
{
  "type": "drag",
  "objective_action": "Prepará",
  "objective_meal": "una colación sin TACC",
  "objective_connector": "para tu amigue",
  "objective_restriction": "con celiaquía"
}
```

**Formato mensaje:**
```json
{
  "type": "drag",
  "objective_label": "Prepará",
  "objective_message": "una colación sin TACC\npara tu amigue"
}
```

### Flujo de datos

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
├── RestrictionLabel: Label    ← "con celiaquía"  (se oculta si no hay restricción)
└── RestrictionLine: ColorRect ← separador delgado final (se oculta junto con RestrictionLabel)
```


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
