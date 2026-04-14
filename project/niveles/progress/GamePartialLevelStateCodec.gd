extends RefCounted
const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _global_state


func _init(global_state):
	_global_state = global_state


func export_track_states(partial_level_states: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		var exported_track_levels: Dictionary = _export_track_levels(
			partial_level_states.get(track_key, {})
		)
		if not exported_track_levels.is_empty():
			result[track_key] = exported_track_levels

	return result


func normalize_track_states(raw_states: Variant) -> Dictionary:
	var states_by_track: Dictionary = raw_states if raw_states is Dictionary else {}
	var result: Dictionary = {}

	for track_key in _global_state.TRACK_KEYS:
		result[track_key] = _normalize_track_levels(
			states_by_track.get(track_key, {}),
			_global_state.get_track_level_count(track_key)
		)

	return result


func normalize_level_state(raw_level_state: Variant) -> Dictionary:
	if not raw_level_state is Dictionary:
		return {}

	var raw_state: Dictionary = raw_level_state
	var run_index: int = _normalize_run_index(raw_state)
	var stored_mechanic_type: String = _read_mechanic_type(raw_state)
	var normalized_mechanic_state: Dictionary = _normalize_mechanic_state(
		raw_state,
		stored_mechanic_type
	)
	return _build_normalized_level_state(
		run_index,
		stored_mechanic_type,
		normalized_mechanic_state
	)


func _build_normalized_level_state(
	run_index: int,
	stored_mechanic_type: String,
	normalized_mechanic_state: Dictionary
) -> Dictionary:
	var resolved_mechanic_type: String = _resolve_mechanic_type(
		stored_mechanic_type,
		run_index,
		normalized_mechanic_state
	)

	if _should_drop_level_state(run_index, normalized_mechanic_state):
		return {}

	var normalized_level_state: Dictionary = {
		_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: resolved_mechanic_type,
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}

	if resolved_mechanic_type == LevelMechanicTypes.PLATE_SORT:
		_append_legacy_plate_sort_fields(
			normalized_level_state,
			normalized_mechanic_state
		)

	return normalized_level_state


func remove_completed_states(partial_level_states: Dictionary) -> void:
	for track_key in _global_state.TRACK_KEYS:
		partial_level_states[track_key] = _filter_pending_track_levels(
			partial_level_states.get(track_key, {}),
			track_key,
			_global_state.get_track_level_count(track_key)
		)


func _export_track_levels(raw_track_levels: Variant) -> Dictionary:
	if not raw_track_levels is Dictionary:
		return {}

	var exported_track_levels: Dictionary = {}
	for raw_key in raw_track_levels.keys():
		var level_key := str(raw_key).strip_edges()
		if level_key.is_empty():
			continue

		var normalized_level_state: Dictionary = normalize_level_state(
			raw_track_levels[raw_key]
		)
		if not normalized_level_state.is_empty():
			exported_track_levels[level_key] = normalized_level_state

	return exported_track_levels


func _normalize_track_levels(
	raw_track_levels: Variant,
	max_level_number: int
) -> Dictionary:
	if not raw_track_levels is Dictionary:
		return {}

	var normalized_track_levels: Dictionary = {}
	for raw_key in raw_track_levels.keys():
		var level_key := str(raw_key).strip_edges()
		if not level_key.is_valid_int():
			continue

		var level_number := clampi(int(level_key), 1, max_level_number)
		var normalized_level_state: Dictionary = normalize_level_state(
			raw_track_levels[raw_key]
		)
		if not normalized_level_state.is_empty():
			normalized_track_levels[str(level_number)] = normalized_level_state

	return normalized_track_levels


func _filter_pending_track_levels(
	raw_track_levels: Variant,
	track_key: String,
	max_level_number: int
) -> Dictionary:
	var normalized_track_levels: Dictionary = _normalize_track_levels(
		raw_track_levels,
		max_level_number
	)
	var pending_track_levels: Dictionary = {}

	for level_key in normalized_track_levels.keys():
		var level_number := int(level_key)
		if _global_state.is_level_completed(track_key, level_number):
			continue
		pending_track_levels[level_key] = normalized_track_levels[level_key]

	return pending_track_levels


func _normalize_run_index(raw_state: Dictionary) -> int:
	return max(
		1,
		int(raw_state.get(_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY, 1))
	)


func _read_mechanic_type(raw_state: Dictionary) -> String:
	return str(
		raw_state.get(_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()


func _normalize_mechanic_state(
	raw_state: Dictionary,
	mechanic_type: String
) -> Dictionary:
	var raw_mechanic_state: Variant = raw_state.get(
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	if _should_use_plate_sort_state(mechanic_type):
		return _normalize_plate_sort_state(raw_state, raw_mechanic_state)
	if raw_mechanic_state is Dictionary:
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return {}


func _should_use_plate_sort_state(mechanic_type: String) -> bool:
	return mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT


func _normalize_plate_sort_state(
	raw_state: Dictionary,
	raw_mechanic_state: Variant
) -> Dictionary:
	var stored_plate_sort_state: Dictionary = _read_stored_plate_sort_state(
		raw_state,
		raw_mechanic_state
	)
	return _build_normalized_plate_sort_state(stored_plate_sort_state)


func _build_normalized_plate_sort_state(stored_plate_sort_state: Dictionary) -> Dictionary:
	var normalized_items: Array = _normalize_plate_sort_items(stored_plate_sort_state)
	var positive_item_ids: Dictionary = _index_positive_plate_sort_items(
		normalized_items
	)
	var normalized_placed_item_ids: Array = _normalize_plate_sort_placed_item_ids(
		stored_plate_sort_state,
		positive_item_ids
	)
	return {
		_global_state.PARTIAL_LEVEL_ITEMS_KEY: normalized_items,
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_item_ids
	}


func _read_stored_plate_sort_state(
	raw_state: Dictionary,
	raw_mechanic_state: Variant
) -> Dictionary:
	if (
		raw_mechanic_state is Dictionary
		and not (raw_mechanic_state as Dictionary).is_empty()
	):
		return raw_mechanic_state
	return {
		_global_state.PARTIAL_LEVEL_ITEMS_KEY: raw_state.get(
			_global_state.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		),
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: raw_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _normalize_plate_sort_items(plate_sort_state: Dictionary) -> Array:
	var normalized_items: Array = []
	var raw_saved_items: Variant = plate_sort_state.get(
		_global_state.PARTIAL_LEVEL_ITEMS_KEY,
		[]
	)
	if not raw_saved_items is Array:
		return normalized_items

	for raw_saved_item in raw_saved_items:
		var normalized_item: Dictionary = _normalize_saved_plate_sort_item(
			raw_saved_item
		)
		if normalized_item.is_empty():
			continue
		normalized_items.append(normalized_item)

	return normalized_items


func _index_positive_plate_sort_items(normalized_items: Array) -> Dictionary:
	var positive_item_ids: Dictionary = {}
	for raw_item in normalized_items:
		if not raw_item is Dictionary:
			continue
		var normalized_item: Dictionary = raw_item
		if not bool(normalized_item.get(_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)):
			continue
		positive_item_ids[
			str(normalized_item.get(_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY, ""))
		] = true
	return positive_item_ids


func _normalize_plate_sort_placed_item_ids(
	plate_sort_state: Dictionary,
	positive_item_ids: Dictionary
) -> Array:
	var normalized_placed_item_ids: Array = []
	var raw_placed_item_ids: Variant = plate_sort_state.get(
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	if not raw_placed_item_ids is Array:
		return normalized_placed_item_ids

	for raw_id in raw_placed_item_ids:
		var item_id := str(raw_id).strip_edges()
		if item_id.is_empty() or normalized_placed_item_ids.has(item_id):
			continue
		if positive_item_ids.has(item_id):
			normalized_placed_item_ids.append(item_id)

	return normalized_placed_item_ids


func _resolve_mechanic_type(
	mechanic_type: String,
	run_index: int,
	normalized_mechanic_state: Dictionary
) -> String:
	if mechanic_type.is_empty() and (
		run_index > 1 or not normalized_mechanic_state.is_empty()
	):
		return LevelMechanicTypes.PLATE_SORT
	return mechanic_type


func _should_drop_level_state(
	run_index: int,
	normalized_mechanic_state: Dictionary
) -> bool:
	return normalized_mechanic_state.is_empty() and run_index <= 1


func _append_legacy_plate_sort_fields(
	normalized_level_state: Dictionary,
	normalized_mechanic_state: Dictionary
) -> void:
	normalized_level_state[_global_state.PARTIAL_LEVEL_ITEMS_KEY] = (
		normalized_mechanic_state.get(_global_state.PARTIAL_LEVEL_ITEMS_KEY, [])
	)
	normalized_level_state[_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = (
		normalized_mechanic_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	)


func _normalize_saved_plate_sort_item(raw_saved_item: Variant) -> Dictionary:
	if not raw_saved_item is Dictionary:
		return {}

	var item_path := str(
		raw_saved_item.get(_global_state.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id := str(
		raw_saved_item.get(_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return {}

	return {
		_global_state.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
		_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
		_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(
			raw_saved_item.get(_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
		)
	}
