## Persistencia del estado parcial de niveles en curso en el save local.
##
## Cuando el jugador está a mitad de un nivel y sale del juego, se guarda
## el estado parcial para poder retomar exactamente donde se quedó.
## Se almacena dentro de progress.partial_level_states en el JSON.
##
## Estructura persistida:
##   partial_level_states:
##     [track_key]:
##       [level_number]:
##         run_index        → Índice de la corrida actual dentro del capítulo
##         mechanic_type    → Tipo de mecánica (ej: "plate_sort")
##         mechanic_state   → Estado interno de la mecánica
##           items          → Array de items en juego
##             item_path    → Ruta del recurso del item
##             instance_id  → ID único de la instancia
##             is_positive  → Si el item es positivo (correcto)
##           placed_item_ids → IDs de items ya colocados por el jugador
##
## Ejemplo en disco:
##   "partial_level_states": {
##       "vegan": {
##           "2": {
##               "run_index": 1,
##               "mechanic_type": "plate_sort",
##               "mechanic_state": { "items": [...], "placed_item_ids": [...] }
##           }
##       }
##   }
##
## Flujo:
##   Runtime (Global._partial_states) → export_estado() → save_data.json
##   save_data.json → import_estado() → Runtime (Global._partial_states)
extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const PLS_RUN_INDEX := "run_index"
const PLS_MECHANIC_TYPE := "mechanic_type"
const PLS_MECHANIC_STATE := "mechanic_state"
const PLS_ITEMS := "items"
const PLS_PLACED_IDS := "placed_item_ids"
const PLS_ITEM_PATH := "item_path"
const PLS_INSTANCE_ID := "instance_id"
const PLS_IS_POSITIVE := "is_positive"
const PLATE_SORT_MECHANIC := "plate_sort"


## Exporta los estados parciales al snapshot de progreso para disco.
func export_estado(partial_states: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var track_states: Dictionary = partial_states.get(track_key, {})
		if track_states.is_empty():
			continue
		var exported: Dictionary = {}
		for level_number in track_states.keys():
			exported[str(level_number)] = track_states[level_number]
		result[track_key] = exported
	return result


## Importa los estados parciales desde el snapshot leído de disco.
func import_estado(
	snapshot: Variant,
	is_level_completed_fn: Callable,
	get_track_level_count_fn: Callable
) -> Dictionary:
	var stored: Dictionary = snapshot if snapshot is Dictionary else {}
	var result: Dictionary = {}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		result[track_key] = _parse_partial_track(
			stored.get(track_key, {}),
			track_key,
			is_level_completed_fn,
			get_track_level_count_fn
		)
	return result


func _parse_partial_track(
	raw: Variant,
	track_key: String,
	is_level_completed_fn: Callable,
	get_track_level_count_fn: Callable
) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var result: Dictionary = {}
	var max_level: int = get_track_level_count_fn.call(track_key)
	for raw_key in raw.keys():
		if not str(raw_key).is_valid_int():
			continue
		var level: int = clampi(int(str(raw_key)), 1, max_level)
		if is_level_completed_fn.call(track_key, level):
			continue
		var parsed: Dictionary = _parse_partial_level(raw[raw_key])
		if not parsed.is_empty():
			result[level] = parsed
	return result


func _parse_partial_level(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var saved: Dictionary = raw
	var run_index: int = max(1, int(saved.get(PLS_RUN_INDEX, 1)))
	var mechanic_type: String = str(saved.get(PLS_MECHANIC_TYPE, "")).strip_edges()
	var raw_mechanic: Variant = saved.get(PLS_MECHANIC_STATE, {})
	var source: Dictionary = (
		raw_mechanic
		if raw_mechanic is Dictionary and not (raw_mechanic as Dictionary).is_empty()
		else saved
	)
	var items: Array = _parse_partial_items(source)
	var placed_ids: Array = _parse_partial_placed_ids(source, items)
	if mechanic_type.is_empty() and (run_index > 1 or not items.is_empty()):
		mechanic_type = PLATE_SORT_MECHANIC
	if items.is_empty() and run_index <= 1:
		return {}
	var mechanic_state: Dictionary = {PLS_ITEMS: items, PLS_PLACED_IDS: placed_ids}
	return {
		PLS_RUN_INDEX: run_index,
		PLS_MECHANIC_TYPE: mechanic_type,
		PLS_MECHANIC_STATE: mechanic_state,
		PLS_ITEMS: items,
		PLS_PLACED_IDS: placed_ids
	}


func _parse_partial_items(source: Dictionary) -> Array:
	var raw_items: Variant = source.get(PLS_ITEMS, [])
	if not raw_items is Array:
		return []
	var items: Array = []
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			continue
		var item_path: String = str(raw_item.get(PLS_ITEM_PATH, "")).strip_edges()
		var instance_id: String = str(raw_item.get(PLS_INSTANCE_ID, "")).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue
		items.append({
			PLS_ITEM_PATH: item_path,
			PLS_INSTANCE_ID: instance_id,
			PLS_IS_POSITIVE: bool(raw_item.get(PLS_IS_POSITIVE, false))
		})
	return items


func _parse_partial_placed_ids(source: Dictionary, items: Array) -> Array:
	var positive_ids: Dictionary = {}
	for item in items:
		if bool(item.get(PLS_IS_POSITIVE, false)):
			positive_ids[str(item.get(PLS_INSTANCE_ID, ""))] = true
	var raw_ids: Variant = source.get(PLS_PLACED_IDS, [])
	if not raw_ids is Array:
		return []
	var result: Array = []
	for raw_id in raw_ids:
		var item_id: String = str(raw_id).strip_edges()
		if not item_id.is_empty() and not result.has(item_id) and positive_ids.has(item_id):
			result.append(item_id)
	return result
