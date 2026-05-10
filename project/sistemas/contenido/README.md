# Sistemas / Contenido

## Flujo principal (contenido/mapa)

El punto de entrada es `NodeContentLoader.gd`.

```
NodeContentLoader.load_from_context(context)
  → si tiene activity_id: load_from_pack(pack_id, activity_id)
      → load_activity(pack_id, activity_id)
          → busca en preguntas.json, arrastres.json y vinculaciones.json
      → ActivityAdapter.to_legacy_node(activity, pack_id, pack, options)
          → si mode == drag_food: filtra items_celiaquia.json por meal_type + categoria
          → si mode == match: convierte pairs a vinculacion_conceptos
          → devuelve nodo runtime drag_drop
  → si falla y tiene json_path: fallback a CargadorDeContenidoDeNodo (legacy)
  → si solo tiene json_path: usa CargadorDeContenidoDeNodo directamente
```

Archivos fuente actuales:

- `res://contenido/mapa/celiaquia_mapa.json`
- `res://contenido/mapa/arrastres.json`
- `res://contenido/mapa/preguntas.json`
- `res://contenido/mapa/vinculaciones.json`
- `res://contenido/catalogos/items_celiaquia.json`

## Cómo crear un drag_food nuevo

Solo necesitás agregar esto en `arrastres.json`:

```json
{
  "id": "drag_merienda_facil",
  "mode": "drag_food",
  "difficulty": 1,
  "prompt": "Arma una merienda apta sin TACC.",
  "target": "Merienda apta",
  "meal": "merienda",
  "pick": { "correct": 2, "incorrect": 1 }
}
```

El runtime busca automáticamente en `items_celiaquia.json` todos los items con `"merienda"` en su `meal_type`, separa los `sin_tacc` (correctos) de los demás (incorrectos), hace shuffle y selecciona. No es necesario listar alimentos manualmente.

## Fuente de verdad de alimentos

`res://contenido/catalogos/items_celiaquia.json`

Cada item define:
- `nombre` — texto visible
- `asset` — ruta al icono PNG
- `categoria` — `sin_tacc` | `con_gluten` | `riesgo`
- `meal_type` — array con: `desayuno`, `merienda`, `colacion`, `almuerzo`, `cena`, `bebida`, `cocina_segura`
- `tags` — opcional, para filtros futuros
- `feedback` — opcional, explicación educativa

Un alimento se define una sola vez. No duplicar en `meal_pools`.

## Flujo legacy (fallback)

1. `CargadorDeContenidoDeNodo.gd` recibe una ruta `json_path`.
2. `AdaptadorContenidoViejo.gd` normaliza rutas viejas y formatos legacy.
3. `CargadorDeContenidoDeNodo.gd` lee el JSON.
4. `AdaptadorContenidoViejo.gd` adapta el shape viejo al shape oficial si hace falta.
5. `ValidadorDeContenidoDeNodo.gd` valida campos obligatorios y contenido por modo.
6. `ValidadorDeContenidoDeNodo.gd` devuelve una version limpia.
7. El minijuego convierte ese nodo limpio a su runtime si necesita un formato propio.

## Validaciones automáticas

`NodeContentLoader._validate_pack_minimal()` valida al cargar el pack:
- Que cada `drag_food` tenga `prompt`, `target`, `meal` válido y `pick` con valores positivos.
- Que el catálogo `items_celiaquia.json` sea válido y tenga suficientes items para el `meal` pedido.

`ActivityAdapter._validate_items_catalog()` valida el catálogo:
- Todos los items tienen `nombre`, `asset`, `categoria` y `meal_type` no vacío.
- `categoria` pertenece a `[sin_tacc, con_gluten, riesgo]`.
- Cada valor de `meal_type` es uno de los permitidos.

## Que se valida (legacy)

`ValidadorDeContenidoDeNodo.gd` valida:

- campos base: `id`, `theme`, `title`, `difficulty`, `mode`, `content`;
- que `content` sea un objeto;
- datos especificos de `quiz_choice`;
- datos especificos de `drag_drop`;
- datos especificos de `vinculacion_conceptos`.

## Que se adapta

`AdaptadorContenidoViejo.gd` existe para que la demo siga aceptando contenido anterior:

- rutas viejas como `res://niveles/nodos/`;
- rutas viejas como `res://preguntas/json_nodos/`;
- JSON plano de preguntas;
- shapes legacy con bloques `node`, `activity`, `question`, `selection` o `drag_and_drop`.

## Que es legacy

Legacy es compatibilidad para contenido viejo. No es la ruta ideal para escribir contenido nuevo.

Contenido nuevo deberia vivir en:

`res://contenido/mapa/`

Y deberia usar estos contratos chicos:

- `celiaquia_mapa.json` usa `games`
- `arrastres.json` define `drag_food`
- `preguntas.json` define `quiz`
- `vinculaciones.json` define `match`

## Que formato espera cada minijuego

- `quiz_choice`: usa `content.question`, `content.correct_answer`, `content.wrong_options` y `content.visual_resource`.
- `drag_drop`: usa `content.instruction`, `content.targets` y `content.items`. El cierre de aprendizaje usa assets de `assets-sistema/ensenanza`.
- `vinculacion_conceptos`: usa `content.instruccion`, `content.conceptos_izquierda`, `content.conceptos_derecha` y `content.teaching_key`.

## Que NO tocar antes de demo

- No cambiar el formato JSON oficial.
- No borrar `AdaptadorContenidoViejo.gd` sin migrar todo el contenido viejo.
- No cambiar nombres de `mode`.
- No cambiar las claves que consumen los minijuegos.
- No mover JSON de lugar.
- No crear otro pipeline de carga.
- No tocar `Global` ni `SaveManager` desde esta carpeta.

## Tests recomendados

Despues de tocar contenido, correr:

- `vincular_conceptos_scene_test.gd`
- `vertical_slice_smoke_test.gd`
