extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _global_state


func _init(global_state):
	_global_state = global_state


func export_track_partial_level_states(partial_level_states: Dictionary) -> Dictionary:
	var exported_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		var raw_states_for_track: Variant = partial_level_states.get(track_key, {})
		if not raw_states_for_track is Dictionary:
			continue

		var exported_states_for_track: Dictionary = {}
		for raw_level_key in raw_states_for_track.keys():
			var level_key: String = str(raw_level_key).strip_edges()
			if level_key.is_empty():
				continue

			var normalized_state: Dictionary = normalize_partial_level_state(
				raw_states_for_track[raw_level_key]
			)
			if normalized_state.is_empty():
				continue

			exported_states_for_track[level_key] = normalized_state

		if not exported_states_for_track.is_empty():
			exported_states_by_track[track_key] = exported_states_for_track
	return exported_states_by_track


func normalize_track_partial_level_states(raw_states: Variant) -> Dictionary:
	var normalized_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		normalized_states_by_track[track_key] = {}

	if not raw_states is Dictionary:
		return normalized_states_by_track

	for track_key in _global_state.TRACK_KEYS:
		var raw_states_for_track: Variant = raw_states.get(track_key, {})
		if not raw_states_for_track is Dictionary:
			continue

		var normalized_states_for_track: Dictionary = {}
		for raw_level_key in raw_states_for_track.keys():
			var level_key: String = _normalize_level_key_for_track(track_key, raw_level_key)
			if level_key.is_empty():
				continue

			var normalized_state: Dictionary = normalize_partial_level_state(
				raw_states_for_track[raw_level_key]
			)
			if normalized_state.is_empty():
				continue

			normalized_states_for_track[level_key] = normalized_state

		normalized_states_by_track[track_key] = normalized_states_for_track
	return normalized_states_by_track


func normalize_partial_level_state(raw_partial_state: Variant) -> Dictionary:
	if not raw_partial_state is Dictionary:
		return {}

	var partial_state: Dictionary = raw_partial_state
	var run_index: int = max(
		1,
		int(partial_state.get(_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY, 1))
	)
	var mechanic_type: String = str(
		partial_state.get(_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var raw_mechanic_state: Variant = partial_state.get(
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	var mechanic_state: Dictionary = {}

	if mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT:
		var plate_sort_state_source: Variant = raw_mechanic_state
		# Compatibilidad legacy: algunos saves viejos guardaban estos datos fuera de mechanic_state.
		if not (
			raw_mechanic_state is Dictionary
			and not (raw_mechanic_state as Dictionary).is_empty()
		):
			plate_sort_state_source = {
				_global_state.PARTIAL_LEVEL_ITEMS_KEY: partial_state.get(
					_global_state.PARTIAL_LEVEL_ITEMS_KEY,
					[]
				),
				_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: partial_state.get(
					_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
					[]
				)
			}
		mechanic_state = _normalize_plate_sort_state(plate_sort_state_source)
	elif raw_mechanic_state is Dictionary:
		mechanic_state = (raw_mechanic_state as Dictionary).duplicate(true)

	if mechanic_type.is_empty() and (run_index > 1 or not mechanic_state.is_empty()):
		mechanic_type = LevelMechanicTypes.PLATE_SORT
	if mechanic_state.is_empty() and run_index <= 1:
		return {}

	var normalized_state: Dictionary = {
		_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY: mechanic_state
	}
	if mechanic_type == LevelMechanicTypes.PLATE_SORT:
		normalized_state[_global_state.PARTIAL_LEVEL_ITEMS_KEY] = mechanic_state.get(
			_global_state.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		)
		normalized_state[_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = mechanic_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	return normalized_state


func remove_completed_level_states(partial_level_states: Dictionary) -> void:
	var normalized_states_by_track: Dictionary = normalize_track_partial_level_states(
		partial_level_states
	)
	for track_key in _global_state.TRACK_KEYS:
		var raw_states_for_track: Variant = normalized_states_by_track.get(track_key, {})
		var normalized_states_for_track: Dictionary = (
			raw_states_for_track if raw_states_for_track is Dictionary else {}
		)
		for level_key in normalized_states_for_track.keys():
			if _global_state.is_level_completed(track_key, int(level_key)):
				normalized_states_for_track.erase(level_key)
		partial_level_states[track_key] = normalized_states_for_track


func _normalize_level_key_for_track(track_key: String, raw_level_key: Variant) -> String:
	var level_key: String = str(raw_level_key).strip_edges()
	if not level_key.is_valid_int():
		return ""

	var level_number: int = clampi(
		int(level_key),
		1,
		_global_state.get_track_level_count(track_key)
	)
	return str(level_number)


func _normalize_plate_sort_state(raw_plate_sort_state: Variant) -> Dictionary:
	if not raw_plate_sort_state is Dictionary:
		return {}

	var plate_sort_state: Dictionary = raw_plate_sort_state
	var normalized_items: Array = _normalize_plate_sort_saved_items(
		plate_sort_state.get(_global_state.PARTIAL_LEVEL_ITEMS_KEY, [])
	)
	var positive_item_id_lookup: Dictionary = _build_positive_plate_sort_item_lookup(
		normalized_items
	)
	var normalized_placed_item_ids: Array = _normalize_plate_sort_saved_positive_ids(
		plate_sort_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		),
		positive_item_id_lookup
	)
	return {
		_global_state.PARTIAL_LEVEL_ITEMS_KEY: normalized_items,
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_item_ids
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
		raw_item.get(_global_state.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		raw_item.get(_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return {}

	return {
		_global_state.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
		_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
		_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(
			raw_item.get(_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
		)
	}


func _build_positive_plate_sort_item_lookup(normalized_items: Array) -> Dictionary:
	var positive_item_id_lookup: Dictionary = {}
	for normalized_item in normalized_items:
		if not normalized_item is Dictionary:
			continue
		if not bool(
			normalized_item.get(_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
		):
			continue

		var instance_id: String = str(
			normalized_item.get(_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
		).strip_edges()
		if instance_id.is_empty():
			continue
		positive_item_id_lookup[instance_id] = true
	return positive_item_id_lookup


func _normalize_plate_sort_saved_positive_ids(
	raw_placed_item_ids: Variant,
	positive_item_id_lookup: Dictionary
) -> Array:
	var normalized_placed_item_ids: Array = []
	if not raw_placed_item_ids is Array:
		return normalized_placed_item_ids

	for raw_item_id in raw_placed_item_ids:
		var item_id: String = str(raw_item_id).strip_edges()
		if item_id.is_empty() or normalized_placed_item_ids.has(item_id):
			continue
		if positive_item_id_lookup.has(item_id):
			normalized_placed_item_ids.append(item_id)
	return normalized_placed_item_ids
