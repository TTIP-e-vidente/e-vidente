extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _manager


func _init(manager):
	_manager = manager


func export_track_partial_level_states(partial_level_states: Dictionary) -> Dictionary:
	var exported_track_states: Dictionary = {}
	for track_key in _manager.TRACK_KEYS:
		var raw_track_states: Variant = partial_level_states.get(track_key, {})
		if not raw_track_states is Dictionary:
			continue
		var exported_states_for_track: Dictionary = {}
		for raw_level_key in raw_track_states.keys():
			var clean_level_key := str(raw_level_key).strip_edges()
			var normalized_state := normalize_partial_level_state(
				raw_track_states[raw_level_key]
			)
			if clean_level_key.is_empty() or normalized_state.is_empty():
				continue
			exported_states_for_track[clean_level_key] = normalized_state
		if exported_states_for_track.is_empty():
			continue
		exported_track_states[track_key] = exported_states_for_track
	return exported_track_states


func normalize_track_partial_level_states(raw_states: Variant) -> Dictionary:
	var normalized_track_states: Dictionary = {}
	for track_key in _manager.TRACK_KEYS:
		normalized_track_states[track_key] = {}
	if not raw_states is Dictionary:
		return normalized_track_states
	for track_key in _manager.TRACK_KEYS:
		var raw_track_states: Variant = raw_states.get(track_key, {})
		if not raw_track_states is Dictionary:
			continue
		var normalized_states_for_track: Dictionary = {}
		for raw_level_key in raw_track_states.keys():
			var clean_level_key := _resolve_stored_level_key(track_key, raw_level_key)
			var normalized_state := normalize_partial_level_state(
				raw_track_states[raw_level_key]
			)
			if clean_level_key.is_empty() or normalized_state.is_empty():
				continue
			normalized_states_for_track[clean_level_key] = normalized_state
		normalized_track_states[track_key] = normalized_states_for_track
	return normalized_track_states


func normalize_partial_level_state(raw_partial_state: Variant) -> Dictionary:
	if not raw_partial_state is Dictionary:
		return {}
	var partial_state: Dictionary = raw_partial_state
	var run_index := max(1, int(partial_state.get(_manager.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)))
	var mechanic_type := str(
		partial_state.get(_manager.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var raw_mechanic_state := partial_state.get(_manager.PARTIAL_LEVEL_MECHANIC_STATE_KEY, {})
	var normalized_mechanic_state: Dictionary = {}

	if mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT:
		var plate_sort_state_source: Variant = raw_mechanic_state
		if not (
			raw_mechanic_state is Dictionary
			and not (raw_mechanic_state as Dictionary).is_empty()
		):
			plate_sort_state_source = {
				_manager.PARTIAL_LEVEL_ITEMS_KEY: partial_state.get(
					_manager.PARTIAL_LEVEL_ITEMS_KEY,
					[]
				),
				_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: partial_state.get(
					_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
					[]
				)
			}
		normalized_mechanic_state = _normalize_plate_sort_partial_state(
			plate_sort_state_source
		)
	elif raw_mechanic_state is Dictionary:
		normalized_mechanic_state = (raw_mechanic_state as Dictionary).duplicate(true)

	if mechanic_type.is_empty() and (run_index > 1 or not normalized_mechanic_state.is_empty()):
		mechanic_type = LevelMechanicTypes.PLATE_SORT
	if normalized_mechanic_state.is_empty() and run_index <= 1:
		return {}

	var normalized_state := {
		_manager.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		_manager.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		_manager.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}
	if mechanic_type == LevelMechanicTypes.PLATE_SORT:
		normalized_state[_manager.PARTIAL_LEVEL_ITEMS_KEY] = normalized_mechanic_state.get(
			_manager.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		)
		normalized_state[_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = (
			normalized_mechanic_state.get(
				_manager.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
				[]
			)
		)
	return normalized_state


func remove_completed_level_states(partial_level_states: Dictionary) -> void:
	for track_key in _manager.TRACK_KEYS:
		var raw_track_states: Variant = partial_level_states.get(track_key, {})
		if not raw_track_states is Dictionary:
			partial_level_states[track_key] = {}
			continue
		var normalized_track_states: Dictionary = {}
		for raw_level_key in raw_track_states.keys():
			var clean_level_key := _resolve_stored_level_key(track_key, raw_level_key)
			var normalized_state := normalize_partial_level_state(
				raw_track_states[raw_level_key]
			)
			if clean_level_key.is_empty() or normalized_state.is_empty():
				continue
			if _manager.is_level_completed(track_key, int(clean_level_key)):
				continue
			normalized_track_states[clean_level_key] = normalized_state
		partial_level_states[track_key] = normalized_track_states


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


# Plate sort sigue siendo la mecanica vigente y arrastra compatibilidad con saves viejos.
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
