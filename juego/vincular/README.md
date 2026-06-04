# Vincular conceptos

Modalidad **match**: tarjetas izquierda/derecha, el jugador arma pares y confirma.

**Contenido:** activities en `res://contenido/mapa/vinculaciones.json` (ids referenciados desde `celiaquia_mapa.json`). Guía: [contenido/README](../contenido/README.md).

## Carga de datos (flujo actual)

1. El mapa pasa contexto con `activity_id` (o `json_path` legacy).
2. `NodeContentLoader.gd` carga la activity del pack.
3. `NodeContentLoader.convertir_vinculacion_a_runtime()` adapta `pairs` al runtime de la escena.
4. Si falla el pack, puede usar fallback vía `CargadorDeContenidoDeNodo.gd` (no agregar contenido nuevo ahí).

`vincular_conceptos.gd` orquesta la escena: sesión, tarjetas, selección, validación, progreso y cierre.

## Tarjeta (`concept_item.gd`)

Estado por tarjeta: `concept_id`, `texto`, `lado`, `par_key`, `vinculada_con`, `tiene_error`, `animar_vinculo`.

`es_correcta()` compara `par_key` con la tarjeta vinculada.

## Flujo en escena

1. `_ready()` — nodos, botones, sesión.
2. `_cargar_datos_de_vinculacion()` — `NodeContentLoader.load_from_context`.
3. `_aplicar_runtime_en_escena()` — conceptos en UI.
4. Selección izquierda → `vincular_con_derecha()` → `confirmar()`.
5. Reintento: tarjeta WRONG al clic pasa a SELECTED sin resetear la pareja entera (ver bitácora E2).
6. `_finalizar_vinculacion()` — save y flujo post-juego.

`quitar_vinculo_anterior_de(derecha)` evita usar la misma derecha en dos izquierdas.

## Qué no tocar sin motivo (demo)

- Guardado, `Global`, `SaveManager`, `PostGameFlowController`.
- Navegación post-juego y nodos de la escena.
- Formato de `vinculaciones.json` (alinear con [contenido/README](../contenido/README.md)).

## Validar

- Smoke: `res://tests/vertical_slice_smoke_test.gd` (incluye reglas de reintento en vincular).
- Probar un nodo del mapa cuyo `games` apunte a un id en `vinculaciones.json`.
