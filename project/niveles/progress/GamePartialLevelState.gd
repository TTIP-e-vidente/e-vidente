extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")

const PLATE_SORT_MECHANIC_TYPE := "plate_sort"

const RUN_INDEX := GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY
const MECHANIC_TYPE := GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY
const MECHANIC_STATE := GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY
const ITEMS := GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY
const PLACED_IDS := GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY
const ITEM_PATH := GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY
const INSTANCE_ID := GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY
const IS_POSITIVE := GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY

# _states usa int como clave de nivel internamente.
# La conversion a string solo ocurre en export/import (borde con disco).
var _states: Dictionary = {}
var _campaign
var _content


func _init(campaign, content) -> void:
	_campaign = campaign
	_content = content
	reset()


func reset() -> void:
	_states = {}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		_states[track_key] = {}


func get_state(track_key: String, level_number: int) -> Dictionary:
	var key: String = _validate_track(track_key)
	var level: int = _clamp_level(key, level_number)
	if level <= 0:
		return {}
	return _states.get(key, {}).get(level, {})


func set_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var key: String = _validate_track(track_key)
	var level: int = _clamp_level(key, level_number)
	if level <= 0:
		return
	var track_states: Dictionary = _states.get(key, {})
	if _campaign.is_completed(key, level) or state.is_empty():
		track_states.erase(level)
	else:
		track_states[level] = state
	_states[key] = track_states


func clear_state(track_key: String, level_number: int) -> void:
	var key: String = _validate_track(track_key)
	var level: int = _clamp_level(key, level_number)
	if level <= 0:
		return
	var track_states: Dictionary = _states.get(key, {})
	track_states.erase(level)
	_states[key] = track_states


func export_states() -> Dictionary:
	var result: Dictionary = {}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var track_states: Dictionary = _states.get(track_key, {})
		if track_states.is_empty():
			continue
		var exported: Dictionary = {}
		for level_number in track_states.keys():
			exported[str(level_number)] = track_states[level_number]
		result[track_key] = exported
	return result


func import_states(snapshot: Variant) -> void:
	var stored: Dictionary = snapshot if snapshot is Dictionary else {}
	_states = {}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		_states[track_key] = _parse_track(stored.get(track_key, {}), track_key)


func _parse_track(raw: Variant, track_key: String) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var result: Dictionary = {}
	var max_level: int = _get_level_count(track_key)
	for raw_key in raw.keys():
		if not str(raw_key).is_valid_int():
			continue
		var level: int = clampi(int(str(raw_key)), 1, max_level)
		if _campaign.is_completed(track_key, level):
			continue
		var parsed: Dictionary = _parse_level(raw[raw_key])
		if not parsed.is_empty():
			result[level] = parsed
	return result


func _parse_level(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var saved: Dictionary = raw
	var run_index: int = max(1, int(saved.get(RUN_INDEX, 1)))
	var mechanic_type: String = str(saved.get(MECHANIC_TYPE, "")).strip_edges()
	var raw_mechanic: Variant = saved.get(MECHANIC_STATE, {})

	# Si mechanic_state tiene datos usarlo; si no, leer desde raiz (formato legado)
	var source: Dictionary = raw_mechanic if raw_mechanic is Dictionary and not (raw_mechanic as Dictionary).is_empty() else saved

	var items: Array = _parse_items(source)
	var placed_ids: Array = _parse_placed_ids(source, items)

	if mechanic_type.is_empty() and (run_index > 1 or not items.is_empty()):
		mechanic_type = PLATE_SORT_MECHANIC_TYPE
	if items.is_empty() and run_index <= 1:
		return {}

	var mechanic_state: Dictionary = {
		ITEMS: items,
		PLACED_IDS: placed_ids
	}
	return {
		RUN_INDEX: run_index,
		MECHANIC_TYPE: mechanic_type,
		MECHANIC_STATE: mechanic_state,
		ITEMS: items,
		PLACED_IDS: placed_ids
	}


func _parse_items(source: Dictionary) -> Array:
	var raw_items: Variant = source.get(ITEMS, [])
	if not raw_items is Array:
		return []
	var items: Array = []
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			continue
		var item_path: String = str(raw_item.get(ITEM_PATH, "")).strip_edges()
		var instance_id: String = str(raw_item.get(INSTANCE_ID, "")).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue
		items.append({
			ITEM_PATH: item_path,
			INSTANCE_ID: instance_id,
			IS_POSITIVE: bool(raw_item.get(IS_POSITIVE, false))
		})
	return items


func _parse_placed_ids(source: Dictionary, items: Array) -> Array:
	var positive_ids: Dictionary = {}
	for item in items:
		if bool(item.get(IS_POSITIVE, false)):
			positive_ids[str(item.get(INSTANCE_ID, ""))] = true
	var raw_ids: Variant = source.get(PLACED_IDS, [])
	if not raw_ids is Array:
		return []
	var result: Array = []
	for raw_id in raw_ids:
		var item_id: String = str(raw_id).strip_edges()
		if not item_id.is_empty() and not result.has(item_id) and positive_ids.has(item_id):
			result.append(item_id)
	return result


func _validate_track(track_key: String) -> String:
	var key: String = track_key.strip_edges()
	if key.is_empty() or not GameTrackCatalog.has_track(key):
		return ""
	return key


func _clamp_level(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return 0
	var max_level: int = _get_level_count(track_key)
	return 0 if max_level <= 0 else clampi(level_number, 1, max_level)


func _get_level_count(track_key: String) -> int:
	var fallback: int = GameTrackCatalog.get_track_level_count(track_key, GameTrackCatalog.DEFAULT_LEVEL_COUNT)
	return _content.get_track_level_count(track_key, fallback)