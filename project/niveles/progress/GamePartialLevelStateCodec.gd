extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _global_state


func _init(global_state):
	_global_state = global_state


func export_track_states(partial_level_states: Dictionary) -> Dictionary:
	var saved_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		var levels = partial_level_states.get(track_key, {})
		if not levels is Dictionary:
			continue

		var saved_levels: Dictionary = {}
		for raw_level_key in levels.keys():
			var level_key = str(raw_level_key).strip_edges()
			if level_key.is_empty():
				continue

			var level_state = read_level_state(levels[raw_level_key])
			if level_state.is_empty():
				continue

			saved_levels[level_key] = level_state

		if not saved_levels.is_empty():
			saved_states_by_track[track_key] = saved_levels
	return saved_states_by_track


func read_track_states(raw_states: Variant) -> Dictionary:
	var saved_states_by_track = raw_states if raw_states is Dictionary else {}
	var cleaned_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		var levels = saved_states_by_track.get(track_key, {})
		var cleaned_levels: Dictionary = {}
		if levels is Dictionary:
			for raw_level_key in levels.keys():
				var level_key = _read_level_key(track_key, raw_level_key)
				if level_key.is_empty():
					continue

				var level_state = read_level_state(levels[raw_level_key])
				if level_state.is_empty():
					continue
				cleaned_levels[level_key] = level_state
		cleaned_states_by_track[track_key] = cleaned_levels
	return cleaned_states_by_track


func read_level_state(raw_level_state: Variant) -> Dictionary:
	if not raw_level_state is Dictionary:
		return {}

	var level_state: Dictionary = raw_level_state
	var run_index: int = max(
		1,
		int(level_state.get(_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY, 1))
	)
	var mechanic_type = str(
		level_state.get(_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var mechanic_state: Dictionary = {}

	if mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT:
		mechanic_state = _read_plate_sort_state(level_state)
	else:
		var raw_mechanic_state = level_state.get(
			_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
			{}
		)
		if raw_mechanic_state is Dictionary:
			mechanic_state = (raw_mechanic_state as Dictionary).duplicate(true)

	if mechanic_type.is_empty() and (run_index > 1 or not mechanic_state.is_empty()):
		mechanic_type = LevelMechanicTypes.PLATE_SORT
	if mechanic_state.is_empty() and run_index <= 1:
		return {}

	var cleaned_level_state: Dictionary = {
		_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY: mechanic_state
	}
	if mechanic_type == LevelMechanicTypes.PLATE_SORT:
		cleaned_level_state[_global_state.PARTIAL_LEVEL_ITEMS_KEY] = mechanic_state.get(
			_global_state.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		)
		cleaned_level_state[_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = mechanic_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	return cleaned_level_state


func remove_completed_states(partial_level_states: Dictionary) -> void:
	for track_key in _global_state.TRACK_KEYS:
		var levels = partial_level_states.get(track_key, {})
		if not levels is Dictionary:
			partial_level_states[track_key] = {}
			continue

		var pending_levels: Dictionary = {}
		for raw_level_key in levels.keys():
			var level_key = _read_level_key(track_key, raw_level_key)
			if level_key.is_empty():
				continue
			if _global_state.is_level_completed(track_key, int(level_key)):
				continue

			var level_state = read_level_state(levels[raw_level_key])
			if level_state.is_empty():
				continue
			pending_levels[level_key] = level_state

		partial_level_states[track_key] = pending_levels


func _read_level_key(track_key: String, raw_level_key: Variant) -> String:
	var level_key = str(raw_level_key).strip_edges()
	if not level_key.is_valid_int():
		return ""

	var level_number = clampi(
		int(level_key),
		1,
		_global_state.get_track_level_count(track_key)
	)
	return str(level_number)


func _read_plate_sort_state(level_state: Dictionary) -> Dictionary:
	var raw_mechanic_state = level_state.get(
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	var plate_sort_state: Dictionary = {}
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		plate_sort_state = raw_mechanic_state
	else:
		plate_sort_state = {
			_global_state.PARTIAL_LEVEL_ITEMS_KEY: level_state.get(
				_global_state.PARTIAL_LEVEL_ITEMS_KEY,
				[]
			),
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: level_state.get(
				_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
				[]
			)
		}

	var items = _read_plate_sort_items(
		plate_sort_state.get(_global_state.PARTIAL_LEVEL_ITEMS_KEY, [])
	)
	var positive_item_ids: Dictionary = {}
	for item in items:
		if not bool(item.get(_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)):
			continue

		var instance_id = str(
			item.get(_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
		).strip_edges()
		if instance_id.is_empty():
			continue
		positive_item_ids[instance_id] = true

	var placed_positive_item_ids: Array = []
	var raw_placed_item_ids = plate_sort_state.get(
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	if raw_placed_item_ids is Array:
		for raw_item_id in raw_placed_item_ids:
			var item_id = str(raw_item_id).strip_edges()
			if item_id.is_empty() or placed_positive_item_ids.has(item_id):
				continue
			if positive_item_ids.has(item_id):
				placed_positive_item_ids.append(item_id)

	return {
		_global_state.PARTIAL_LEVEL_ITEMS_KEY: items,
		_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}


func _read_plate_sort_items(raw_items: Variant) -> Array:
	var items: Array = []
	if not raw_items is Array:
		return items

	for raw_item in raw_items:
		var item = _read_plate_sort_item(raw_item)
		if item.is_empty():
			continue
		items.append(item)
	return items


func _read_plate_sort_item(raw_item: Variant) -> Dictionary:
	if not raw_item is Dictionary:
		return {}

	var item_path = str(
		raw_item.get(_global_state.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id = str(
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
