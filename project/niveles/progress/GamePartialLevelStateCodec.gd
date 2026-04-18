extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _global_state


func _init(global_state):
	_global_state = global_state


func export_track_states(partial_level_states: Dictionary) -> Dictionary:
	var exported_states_by_track: Dictionary = {}

	for track_key in _global_state.TRACK_KEYS:
		var exported_track_level_states: Dictionary = _export_track_level_states(
			partial_level_states.get(track_key, {})
		)
		if exported_track_level_states.is_empty():
			continue

		exported_states_by_track[track_key] = exported_track_level_states

	return exported_states_by_track


func normalize_track_states(raw_states: Variant) -> Dictionary:
	var raw_states_by_track: Dictionary = raw_states if raw_states is Dictionary else {}
	var normalized_states_by_track: Dictionary = {}

	for track_key in _global_state.TRACK_KEYS:
		normalized_states_by_track[track_key] = _normalize_track_level_states(
			raw_states_by_track.get(track_key, {}),
			_global_state.get_track_level_count(track_key)
		)

	return normalized_states_by_track


func normalize_level_state(raw_level_state: Variant) -> Dictionary:
	if not raw_level_state is Dictionary:
		return {}

	var raw_saved_level_state: Dictionary = raw_level_state
	var saved_run_index: int = max(
		1,
		int(raw_saved_level_state.get(_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY, 1))
	)
	var stored_mechanic_type: String = str(
		raw_saved_level_state.get(_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var normalized_mechanic_state: Dictionary = _normalize_saved_mechanic_state(
		raw_saved_level_state,
		stored_mechanic_type
	)

	var resolved_mechanic_type: String = stored_mechanic_type
	if resolved_mechanic_type.is_empty() and (
		saved_run_index > 1 or not normalized_mechanic_state.is_empty()
	):
		resolved_mechanic_type = LevelMechanicTypes.PLATE_SORT

	if normalized_mechanic_state.is_empty() and saved_run_index <= 1:
		return {}

	var normalized_level_state: Dictionary = {
		_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY: saved_run_index,
		_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: resolved_mechanic_type,
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}

	if resolved_mechanic_type == LevelMechanicTypes.PLATE_SORT:
		normalized_level_state[_global_state.PARTIAL_LEVEL_ITEMS_KEY] = (
			normalized_mechanic_state.get(_global_state.PARTIAL_LEVEL_ITEMS_KEY, [])
		)
		normalized_level_state[_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = (
			normalized_mechanic_state.get(
				_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
				[]
			)
		)

	return normalized_level_state


func remove_completed_states(partial_level_states: Dictionary) -> void:
	for track_key in _global_state.TRACK_KEYS:
		partial_level_states[track_key] = _remove_completed_track_level_states(
			partial_level_states.get(track_key, {}),
			track_key,
			_global_state.get_track_level_count(track_key)
		)


func _export_track_level_states(raw_track_level_states: Variant) -> Dictionary:
	if not raw_track_level_states is Dictionary:
		return {}

	var exported_track_level_states: Dictionary = {}
	for raw_level_key in raw_track_level_states.keys():
		var level_key := str(raw_level_key).strip_edges()
		if level_key.is_empty():
			continue

		var normalized_level_state: Dictionary = normalize_level_state(
			raw_track_level_states[raw_level_key]
		)
		if normalized_level_state.is_empty():
			continue

		exported_track_level_states[level_key] = normalized_level_state

	return exported_track_level_states


func _normalize_track_level_states(
	raw_track_level_states: Variant,
	max_level_number: int
) -> Dictionary:
	if not raw_track_level_states is Dictionary:
		return {}

	var normalized_track_level_states: Dictionary = {}
	for raw_level_key in raw_track_level_states.keys():
		var level_key := str(raw_level_key).strip_edges()
		if not level_key.is_valid_int():
			continue

		var level_number := clampi(int(level_key), 1, max_level_number)
		var normalized_level_state: Dictionary = normalize_level_state(
			raw_track_level_states[raw_level_key]
		)
		if normalized_level_state.is_empty():
			continue

		normalized_track_level_states[str(level_number)] = normalized_level_state

	return normalized_track_level_states


func _remove_completed_track_level_states(
	raw_track_level_states: Variant,
	track_key: String,
	max_level_number: int
) -> Dictionary:
	if not raw_track_level_states is Dictionary:
		return {}

	var pending_track_level_states: Dictionary = {}
	for raw_level_key in raw_track_level_states.keys():
		var level_key := str(raw_level_key).strip_edges()
		if not level_key.is_valid_int():
			continue

		var level_number := clampi(int(level_key), 1, max_level_number)
		if _global_state.is_level_completed(track_key, level_number):
			continue

		var normalized_level_state: Dictionary = normalize_level_state(
			raw_track_level_states[raw_level_key]
		)
		if normalized_level_state.is_empty():
			continue

		pending_track_level_states[str(level_number)] = normalized_level_state

	return pending_track_level_states


func _normalize_saved_mechanic_state(
	raw_saved_level_state: Dictionary,
	mechanic_type: String
) -> Dictionary:
	var raw_mechanic_state: Variant = raw_saved_level_state.get(
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)

	if mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT:
		return _normalize_plate_sort_mechanic_state(
			raw_saved_level_state,
			raw_mechanic_state
		)

	if raw_mechanic_state is Dictionary:
		return (raw_mechanic_state as Dictionary).duplicate(true)

	return {}


func _normalize_plate_sort_mechanic_state(
	raw_saved_level_state: Dictionary,
	raw_mechanic_state: Variant
) -> Dictionary:
	var saved_plate_sort_state: Dictionary = _read_saved_plate_sort_state(
		raw_saved_level_state,
		raw_mechanic_state
	)
	var normalized_saved_items: Array = []
	var valid_positive_item_ids: Dictionary = {}

	var raw_saved_items: Variant = saved_plate_sort_state.get(
		_global_state.PARTIAL_LEVEL_ITEMS_KEY,
		[]
	)
	if raw_saved_items is Array:
		for raw_saved_item in raw_saved_items:
			var normalized_saved_item: Dictionary = _normalize_saved_plate_sort_item(
				raw_saved_item
			)
			if normalized_saved_item.is_empty():
				continue

			normalized_saved_items.append(normalized_saved_item)
			if bool(
				normalized_saved_item.get(
					_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY,
					false
				)
			):
				var instance_id := str(
					normalized_saved_item.get(
						_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY,
						""
					)
				)
				valid_positive_item_ids[instance_id] = true

	var normalized_placed_positive_item_ids: Array = (
		_normalize_saved_plate_sort_placed_item_ids(
			saved_plate_sort_state,
			valid_positive_item_ids
		)
	)
	return {
		_global_state.PARTIAL_LEVEL_ITEMS_KEY: normalized_saved_items,
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_positive_item_ids
	}


func _read_saved_plate_sort_state(
	raw_saved_level_state: Dictionary,
	raw_mechanic_state: Variant
) -> Dictionary:
	# Save actual: la mecanica vive dentro de mechanic_state.
	# Compatibilidad legacy: items e ids podian llegar en la raiz del estado.
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		return raw_mechanic_state

	return {
		_global_state.PARTIAL_LEVEL_ITEMS_KEY: raw_saved_level_state.get(
			_global_state.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		),
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: raw_saved_level_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _normalize_saved_plate_sort_placed_item_ids(
	saved_plate_sort_state: Dictionary,
	valid_positive_item_ids: Dictionary
) -> Array:
	var normalized_placed_positive_item_ids: Array = []
	var raw_placed_item_ids: Variant = saved_plate_sort_state.get(
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	if not raw_placed_item_ids is Array:
		return normalized_placed_positive_item_ids

	for raw_item_id in raw_placed_item_ids:
		var item_id := str(raw_item_id).strip_edges()
		if item_id.is_empty() or normalized_placed_positive_item_ids.has(item_id):
			continue
		if not valid_positive_item_ids.has(item_id):
			continue

		normalized_placed_positive_item_ids.append(item_id)

	return normalized_placed_positive_item_ids


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
