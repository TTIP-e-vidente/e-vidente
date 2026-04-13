extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _global_state


func _init(global_state):
	_global_state = global_state


func export_track_states(partial_level_states: Dictionary) -> Dictionary:
	var saved_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		var raw_levels: Variant = partial_level_states.get(track_key, {})
		if not raw_levels is Dictionary:
			continue

		var saved_levels: Dictionary = {}
		for raw_level_key in raw_levels.keys():
			var level_key: String = str(raw_level_key).strip_edges()
			if level_key.is_empty():
				continue

			var level_state: Dictionary = read_level_state(raw_levels[raw_level_key])
			if level_state.is_empty():
				continue

			saved_levels[level_key] = level_state

		if not saved_levels.is_empty():
			saved_states_by_track[track_key] = saved_levels
	return saved_states_by_track


func read_track_states(raw_states: Variant) -> Dictionary:
	var raw_states_by_track: Dictionary = raw_states if raw_states is Dictionary else {}
	var saved_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		var raw_levels: Variant = raw_states_by_track.get(track_key, {})
		var saved_levels: Dictionary = {}
		if raw_levels is Dictionary:
			var max_level_number: int = _global_state.get_track_level_count(track_key)
			for raw_level_key in raw_levels.keys():
				var level_key: String = str(raw_level_key).strip_edges()
				if not level_key.is_valid_int():
					continue

				var level_number: int = clampi(int(level_key), 1, max_level_number)
				var level_state: Dictionary = read_level_state(raw_levels[raw_level_key])
				if level_state.is_empty():
					continue
				saved_levels[str(level_number)] = level_state
		saved_states_by_track[track_key] = saved_levels
	return saved_states_by_track


func read_level_state(raw_level_state: Variant) -> Dictionary:
	if not raw_level_state is Dictionary:
		return {}

	var raw_state: Dictionary = raw_level_state
	var run_index: int = max(
		1,
		int(raw_state.get(_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY, 1))
	)
	var mechanic_type: String = str(
		raw_state.get(_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var mechanic_state: Dictionary = {}
	var raw_mechanic_state: Variant = raw_state.get(
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)

	if mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT:
		var plate_sort_state: Dictionary = {}

		if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
			plate_sort_state = raw_mechanic_state
		else:
			plate_sort_state = {
				_global_state.PARTIAL_LEVEL_ITEMS_KEY: raw_state.get(
					_global_state.PARTIAL_LEVEL_ITEMS_KEY,
					[]
				),
				_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: raw_state.get(
					_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
					[]
				)
			}

		var saved_items: Array = []
		var positive_item_ids: Dictionary = {}
		var raw_items: Variant = plate_sort_state.get(
			_global_state.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		)
		if raw_items is Array:
			for raw_item in raw_items:
				if not raw_item is Dictionary:
					continue

				var item_path: String = str(
					raw_item.get(_global_state.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
				).strip_edges()
				var instance_id: String = str(
					raw_item.get(_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
				).strip_edges()
				if item_path.is_empty() or instance_id.is_empty():
					continue

				var is_positive: bool = bool(
					raw_item.get(_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
				)
				saved_items.append(
					{
						_global_state.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
						_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
						_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY: is_positive
					}
				)
				if is_positive:
					positive_item_ids[instance_id] = true

		var placed_positive_item_ids: Array = []
		var raw_placed_item_ids: Variant = plate_sort_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
		if raw_placed_item_ids is Array:
			for raw_item_id in raw_placed_item_ids:
				var item_id: String = str(raw_item_id).strip_edges()
				if item_id.is_empty() or placed_positive_item_ids.has(item_id):
					continue
				if positive_item_ids.has(item_id):
					placed_positive_item_ids.append(item_id)

		mechanic_state = {
			_global_state.PARTIAL_LEVEL_ITEMS_KEY: saved_items,
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
		}
	elif raw_mechanic_state is Dictionary:
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
		var raw_levels: Variant = partial_level_states.get(track_key, {})
		if not raw_levels is Dictionary:
			partial_level_states[track_key] = {}
			continue

		var pending_levels: Dictionary = {}
		var max_level_number: int = _global_state.get_track_level_count(track_key)
		for raw_level_key in raw_levels.keys():
			var level_key: String = str(raw_level_key).strip_edges()
			if not level_key.is_valid_int():
				continue

			var level_number: int = clampi(int(level_key), 1, max_level_number)
			if _global_state.is_level_completed(track_key, level_number):
				continue

			var level_state: Dictionary = read_level_state(raw_levels[raw_level_key])
			if level_state.is_empty():
				continue
			pending_levels[str(level_number)] = level_state

		partial_level_states[track_key] = pending_levels
