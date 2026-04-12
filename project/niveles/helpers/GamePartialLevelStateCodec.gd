extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _manager


func _init(manager):
	_manager = manager


func export_track_partial_level_states(partial_level_states: Dictionary) -> Dictionary:
	var exported_track_states: Dictionary = {}
	for track_key in _manager.TRACK_KEYS:
		var normalized_track_states: Dictionary = _export_states_for_track(
			partial_level_states.get(track_key, {})
		)
		if not normalized_track_states.is_empty():
			exported_track_states[track_key] = normalized_track_states
	return exported_track_states


func normalize_track_partial_level_states(raw_states: Variant) -> Dictionary:
	var normalized_track_states: Dictionary = _build_empty_partial_state_map()
	if not raw_states is Dictionary:
		return normalized_track_states
	for track_key in _manager.TRACK_KEYS:
		normalized_track_states[track_key] = _normalize_states_for_track(
			track_key,
			raw_states.get(track_key, {})
		)
	return normalized_track_states


func normalize_partial_level_state(raw_partial_state: Variant) -> Dictionary:
	if not raw_partial_state is Dictionary:
		return {}
	var run_index: int = _resolve_saved_run_index(raw_partial_state)
	var normalized_mechanic_state: Dictionary = _normalize_saved_mechanic_state(
		raw_partial_state
	)
	var mechanic_type: String = _resolve_saved_mechanic_type(
		raw_partial_state,
		run_index,
		normalized_mechanic_state
	)
	if _should_drop_partial_level_state(run_index, normalized_mechanic_state):
		return {}
	var normalized_state: Dictionary = _build_normalized_partial_level_state(
		run_index,
		mechanic_type,
		normalized_mechanic_state
	)
	return _append_legacy_plate_sort_fields(
		normalized_state,
		mechanic_type,
		normalized_mechanic_state
	)


func remove_completed_level_states(partial_level_states: Dictionary) -> void:
	for track_key in _manager.TRACK_KEYS:
		partial_level_states[track_key] = _remove_completed_states_for_track(
			track_key,
			partial_level_states.get(track_key, {})
		)


func _build_empty_partial_state_map() -> Dictionary:
	var empty_partial_state_map: Dictionary = {}
	for track_key in _manager.TRACK_KEYS:
		empty_partial_state_map[track_key] = {}
	return empty_partial_state_map


func _export_states_for_track(raw_track_states: Variant) -> Dictionary:
	if not raw_track_states is Dictionary:
		return {}
	var exported_states_for_track: Dictionary = {}
	for raw_level_key in raw_track_states.keys():
		var clean_level_key: String = _resolve_export_level_key(raw_level_key)
		var normalized_state: Dictionary = normalize_partial_level_state(
			raw_track_states[raw_level_key]
		)
		if clean_level_key.is_empty() or normalized_state.is_empty():
			continue
		exported_states_for_track[clean_level_key] = normalized_state
	return exported_states_for_track


func _normalize_states_for_track(track_key: String, raw_track_states: Variant) -> Dictionary:
	if not raw_track_states is Dictionary:
		return {}
	var normalized_states_for_track: Dictionary = {}
	for raw_level_key in raw_track_states.keys():
		var clean_level_key: String = _resolve_stored_level_key(track_key, raw_level_key)
		var normalized_state: Dictionary = normalize_partial_level_state(
			raw_track_states[raw_level_key]
		)
		if clean_level_key.is_empty() or normalized_state.is_empty():
			continue
		normalized_states_for_track[clean_level_key] = normalized_state
	return normalized_states_for_track


func _resolve_export_level_key(raw_level_key: Variant) -> String:
	return str(raw_level_key).strip_edges()


func _resolve_stored_level_key(track_key: String, raw_level_key: Variant) -> String:
	var clean_level_key: String = str(raw_level_key).strip_edges()
	if not clean_level_key.is_valid_int():
		return ""
	var clean_level_number := clampi(
		int(clean_level_key),
		1,
		_manager.get_track_level_count(track_key)
	)
	return str(clean_level_number)


func _resolve_saved_run_index(raw_partial_state: Dictionary) -> int:
	return max(1, int(raw_partial_state.get(_manager.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)))


func _resolve_saved_mechanic_type(
	raw_partial_state: Dictionary,
	run_index: int,
	normalized_mechanic_state: Dictionary
) -> String:
	var mechanic_type: String = str(
		raw_partial_state.get(_manager.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	if mechanic_type.is_empty() and (run_index > 1 or not normalized_mechanic_state.is_empty()):
		return LevelMechanicTypes.PLATE_SORT
	return mechanic_type


func _should_drop_partial_level_state(
	run_index: int,
	normalized_mechanic_state: Dictionary
) -> bool:
	return normalized_mechanic_state.is_empty() and run_index <= 1


func _build_normalized_partial_level_state(
	run_index: int,
	mechanic_type: String,
	normalized_mechanic_state: Dictionary
) -> Dictionary:
	return {
		_manager.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		_manager.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		_manager.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}


func _append_legacy_plate_sort_fields(
	normalized_state: Dictionary,
	mechanic_type: String,
	normalized_mechanic_state: Dictionary
) -> Dictionary:
	if mechanic_type != LevelMechanicTypes.PLATE_SORT:
		return normalized_state
	normalized_state[_manager.PARTIAL_LEVEL_ITEMS_KEY] = normalized_mechanic_state.get(
		_manager.PARTIAL_LEVEL_ITEMS_KEY,
		[]
	)
	normalized_state[_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = normalized_mechanic_state.get(
		_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	return normalized_state


func _remove_completed_states_for_track(track_key: String, raw_track_states: Variant) -> Dictionary:
	var normalized_track_states: Dictionary = _normalize_states_for_track(track_key, raw_track_states)
	for level_key in normalized_track_states.keys():
		if _manager.is_level_completed(track_key, int(level_key)):
			normalized_track_states.erase(level_key)
	return normalized_track_states


func _normalize_saved_mechanic_state(raw_partial_state: Dictionary) -> Dictionary:
	var mechanic_type: String = str(
		raw_partial_state.get(_manager.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var raw_mechanic_state: Variant = raw_partial_state.get(
		_manager.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	var clean_mechanic_type: String = mechanic_type.strip_edges()
	if clean_mechanic_type.is_empty() or clean_mechanic_type == LevelMechanicTypes.PLATE_SORT:
		return _normalize_plate_sort_partial_state(
			_resolve_plate_sort_partial_state_source(raw_mechanic_state, raw_partial_state)
		)
	if raw_mechanic_state is Dictionary:
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return {}


func _resolve_plate_sort_partial_state_source(
	raw_mechanic_state: Variant,
	raw_partial_state: Dictionary
) -> Variant:
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		return raw_mechanic_state
	return {
		_manager.PARTIAL_LEVEL_ITEMS_KEY: raw_partial_state.get(
			_manager.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		),
		_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: raw_partial_state.get(
			_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _normalize_plate_sort_partial_state(raw_plate_sort_state: Variant) -> Dictionary:
	if not raw_plate_sort_state is Dictionary:
		return {}
	var plate_sort_state: Dictionary = raw_plate_sort_state
	var normalized_items: Array = _normalize_plate_sort_saved_items(
		plate_sort_state.get(_manager.PARTIAL_LEVEL_ITEMS_KEY, [])
	)
	var valid_positive_item_ids: Dictionary = _build_positive_item_id_index(normalized_items)
	var normalized_placed_item_ids: Array = _normalize_plate_sort_placed_item_ids(
		plate_sort_state.get(
			_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		),
		valid_positive_item_ids
	)
	return {
		_manager.PARTIAL_LEVEL_ITEMS_KEY: normalized_items,
		_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_item_ids
	}


func _normalize_plate_sort_saved_items(raw_items: Variant) -> Array:
	var normalized_items: Array = []
	if not raw_items is Array:
		return normalized_items
	for raw_item in raw_items:
		var normalized_item: Dictionary = _normalize_plate_sort_saved_item(raw_item)
		if normalized_item.is_empty():
			continue
		normalized_items.append(normalized_item)
	return normalized_items


func _normalize_plate_sort_saved_item(raw_item: Variant) -> Dictionary:
	if not raw_item is Dictionary:
		return {}
	var item_path: String = str(
		raw_item.get(_manager.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		raw_item.get(_manager.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return {}
	return {
		_manager.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
		_manager.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
		_manager.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(
			raw_item.get(_manager.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
		)
	}


func _build_positive_item_id_index(normalized_items: Array) -> Dictionary:
	var positive_item_id_index: Dictionary = {}
	for normalized_item in normalized_items:
		if not normalized_item is Dictionary:
			continue
		if not bool(normalized_item.get(_manager.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)):
			continue
		var instance_id: String = str(
			normalized_item.get(_manager.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
		).strip_edges()
		if instance_id.is_empty():
			continue
		positive_item_id_index[instance_id] = true
	return positive_item_id_index


func _normalize_plate_sort_placed_item_ids(
	raw_placed_item_ids: Variant,
	valid_positive_item_ids: Dictionary
) -> Array:
	var normalized_placed_item_ids: Array = []
	if not raw_placed_item_ids is Array:
		return normalized_placed_item_ids
	for raw_item_id in raw_placed_item_ids:
		var clean_item_id: String = str(raw_item_id).strip_edges()
		if clean_item_id.is_empty() or normalized_placed_item_ids.has(clean_item_id):
			continue
		if valid_positive_item_ids.has(clean_item_id):
			normalized_placed_item_ids.append(clean_item_id)
	return normalized_placed_item_ids
