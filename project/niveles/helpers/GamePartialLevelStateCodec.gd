extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _manager


func _init(manager):
	_manager = manager


func export_partial_level_states(partial_level_states: Dictionary) -> Dictionary:
	var exported_states: Dictionary = {}
	for track_key in _manager.TRACK_KEYS:
		var raw_track_states: Variant = partial_level_states.get(track_key, {})
		if not raw_track_states is Dictionary:
			continue
		var normalized_track_states: Dictionary = {}
		for raw_level_key in raw_track_states.keys():
			var clean_level_key: String = str(raw_level_key).strip_edges()
			var normalized_state: Dictionary = normalize_partial_level_state(raw_track_states[raw_level_key])
			if clean_level_key.is_empty() or normalized_state.is_empty():
				continue
			normalized_track_states[clean_level_key] = normalized_state
		if not normalized_track_states.is_empty():
			exported_states[track_key] = normalized_track_states
	return exported_states


func normalize_partial_level_states(raw_states: Variant) -> Dictionary:
	var normalized_states: Dictionary = _build_default_partial_level_states()
	if not raw_states is Dictionary:
		return normalized_states
	for track_key in _manager.TRACK_KEYS:
		var raw_track_states: Variant = raw_states.get(track_key, {})
		if not raw_track_states is Dictionary:
			continue
		var normalized_track_states: Dictionary = {}
		for raw_level_key in raw_track_states.keys():
			var clean_level_key: String = str(raw_level_key).strip_edges()
			if not clean_level_key.is_valid_int():
				continue
			var clean_level_number := clampi(int(clean_level_key), 1, _manager.get_track_level_count(track_key))
			var normalized_state: Dictionary = normalize_partial_level_state(raw_track_states[raw_level_key])
			if normalized_state.is_empty():
				continue
			normalized_track_states[str(clean_level_number)] = normalized_state
		normalized_states[track_key] = normalized_track_states
	return normalized_states


func normalize_partial_level_state(raw_state: Variant) -> Dictionary:
	if not raw_state is Dictionary:
		return {}
	var run_index: int = max(1, int(raw_state.get(_manager.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)))
	var mechanic_type: String = str(raw_state.get(_manager.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")).strip_edges()
	var raw_mechanic_state: Variant = raw_state.get(_manager.PARTIAL_LEVEL_MECHANIC_STATE_KEY, {})
	var normalized_mechanic_state: Dictionary = _normalize_mechanic_state(mechanic_type, raw_mechanic_state, raw_state)
	if mechanic_type.is_empty() and (run_index > 1 or not normalized_mechanic_state.is_empty()):
		mechanic_type = LevelMechanicTypes.PLATE_SORT
	if normalized_mechanic_state.is_empty() and run_index <= 1:
		return {}
	var normalized_state: Dictionary = {
		_manager.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		_manager.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		_manager.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}
	if mechanic_type == LevelMechanicTypes.PLATE_SORT:
		normalized_state[_manager.PARTIAL_LEVEL_ITEMS_KEY] = normalized_mechanic_state.get(_manager.PARTIAL_LEVEL_ITEMS_KEY, [])
		normalized_state[_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = normalized_mechanic_state.get(_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	return normalized_state


func prune_partial_level_states(partial_level_states: Dictionary) -> void:
	for track_key in _manager.TRACK_KEYS:
		var track_states = partial_level_states.get(track_key, {})
		if not track_states is Dictionary:
			partial_level_states[track_key] = {}
			continue
		for raw_level_key in track_states.keys():
			var clean_level_key := str(raw_level_key).strip_edges()
			if not clean_level_key.is_valid_int():
				track_states.erase(raw_level_key)
				continue
			var level_number := clampi(int(clean_level_key), 1, _manager.get_track_level_count(track_key))
			if _manager._is_level_completed(track_key, level_number):
				track_states.erase(raw_level_key)
		partial_level_states[track_key] = track_states


func _build_default_partial_level_states() -> Dictionary:
	var default_states: Dictionary = {}
	for track_key in _manager.TRACK_KEYS:
		default_states[track_key] = {}
	return default_states


func _normalize_mechanic_state(mechanic_type: String, raw_mechanic_state: Variant, raw_state: Dictionary) -> Dictionary:
	var clean_mechanic_type: String = mechanic_type.strip_edges()
	if clean_mechanic_type.is_empty() or clean_mechanic_type == LevelMechanicTypes.PLATE_SORT:
		var plate_sort_source: Variant = raw_mechanic_state
		if not plate_sort_source is Dictionary or (plate_sort_source as Dictionary).is_empty():
			plate_sort_source = {
				_manager.PARTIAL_LEVEL_ITEMS_KEY: raw_state.get(_manager.PARTIAL_LEVEL_ITEMS_KEY, []),
				_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: raw_state.get(_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
			}
		return _normalize_plate_sort_mechanic_state(plate_sort_source)
	if raw_mechanic_state is Dictionary:
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return {}


func _normalize_plate_sort_mechanic_state(raw_mechanic_state: Variant) -> Dictionary:
	if not raw_mechanic_state is Dictionary:
		return {}
	var raw_items: Variant = raw_mechanic_state.get(_manager.PARTIAL_LEVEL_ITEMS_KEY, [])
	var raw_placed_item_ids: Variant = raw_mechanic_state.get(_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	var normalized_items: Array = []
	var positive_item_ids: Dictionary = {}
	if raw_items is Array:
		for raw_item in raw_items:
			if not raw_item is Dictionary:
				continue
			var item_path: String = str(raw_item.get(_manager.PARTIAL_LEVEL_ITEM_PATH_KEY, "")).strip_edges()
			var instance_id: String = str(raw_item.get(_manager.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")).strip_edges()
			if item_path.is_empty() or instance_id.is_empty():
				continue
			var normalized_item: Dictionary = {
				_manager.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
				_manager.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
				_manager.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(raw_item.get(_manager.PARTIAL_LEVEL_IS_POSITIVE_KEY, false))
			}
			normalized_items.append(normalized_item)
			if bool(normalized_item.get(_manager.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)):
				positive_item_ids[instance_id] = true
	var normalized_placed_item_ids: Array = []
	if raw_placed_item_ids is Array:
		for raw_item_id in raw_placed_item_ids:
			var clean_item_id: String = str(raw_item_id).strip_edges()
			if clean_item_id.is_empty() or normalized_placed_item_ids.has(clean_item_id):
				continue
			if positive_item_ids.has(clean_item_id):
				normalized_placed_item_ids.append(clean_item_id)
	return {
		_manager.PARTIAL_LEVEL_ITEMS_KEY: normalized_items,
		_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_item_ids
	}