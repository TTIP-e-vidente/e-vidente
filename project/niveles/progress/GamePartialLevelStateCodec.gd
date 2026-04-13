extends RefCounted

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _global_state


func _init(global_state):
	_global_state = global_state


func export_track_states(partial_level_states: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		var raw_track_levels: Variant = partial_level_states.get(track_key, {})
		if not raw_track_levels is Dictionary:
			continue

		var exported_track_levels: Dictionary = {}
		for raw_key in raw_track_levels.keys():
			var level_key := str(raw_key).strip_edges()
			if level_key.is_empty():
				continue

			var normalized_level_state := normalize_level_state(
				raw_track_levels[raw_key]
			)
			if not normalized_level_state.is_empty():
				exported_track_levels[level_key] = normalized_level_state

		if not exported_track_levels.is_empty():
			result[track_key] = exported_track_levels

	return result


func normalize_track_states(raw_states: Variant) -> Dictionary:
	var states_by_track: Dictionary = raw_states if raw_states is Dictionary else {}
	var result: Dictionary = {}

	for track_key in _global_state.TRACK_KEYS:
		var raw_track_levels: Variant = states_by_track.get(track_key, {})
		var normalized_track_levels: Dictionary = {}

		if raw_track_levels is Dictionary:
			var max_level_number: int = _global_state.get_track_level_count(track_key)
			for raw_key in raw_track_levels.keys():
				var level_key := str(raw_key).strip_edges()
				if not level_key.is_valid_int():
					continue

				var level_number := clampi(int(level_key), 1, max_level_number)
				var normalized_level_state := normalize_level_state(
					raw_track_levels[raw_key]
				)
				if not normalized_level_state.is_empty():
					normalized_track_levels[str(level_number)] = normalized_level_state

		result[track_key] = normalized_track_levels

	return result


func normalize_level_state(raw_level_state: Variant) -> Dictionary:
	if not raw_level_state is Dictionary:
		return {}

	var raw_state: Dictionary = raw_level_state
	var run_index: int = max(
		1,
		int(raw_state.get(_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY, 1))
	)
	var mechanic_type := str(
		raw_state.get(_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var raw_mechanic_state: Variant = raw_state.get(
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	var normalized_mechanic_state: Dictionary = {}

	if mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT:
		var plate_sort_state: Dictionary = {}
		if (
			raw_mechanic_state is Dictionary
			and not (raw_mechanic_state as Dictionary).is_empty()
		):
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

		var positive_item_ids: Dictionary = {}
		var normalized_items: Array = []
		var raw_saved_items: Variant = plate_sort_state.get(
			_global_state.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		)
		if raw_saved_items is Array:
			for raw_saved_item in raw_saved_items:
				var normalized_item := _normalize_saved_plate_sort_item(raw_saved_item)
				if normalized_item.is_empty():
					continue
				normalized_items.append(normalized_item)
				if normalized_item[_global_state.PARTIAL_LEVEL_IS_POSITIVE_KEY]:
					positive_item_ids[
						normalized_item[_global_state.PARTIAL_LEVEL_INSTANCE_ID_KEY]
					] = true

		var normalized_placed_item_ids: Array = []
		var raw_placed_item_ids: Variant = plate_sort_state.get(
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
		if raw_placed_item_ids is Array:
			for raw_id in raw_placed_item_ids:
				var item_id := str(raw_id).strip_edges()
				if item_id.is_empty() or normalized_placed_item_ids.has(item_id):
					continue
				if positive_item_ids.has(item_id):
					normalized_placed_item_ids.append(item_id)

		normalized_mechanic_state = {
			_global_state.PARTIAL_LEVEL_ITEMS_KEY: normalized_items,
			_global_state.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_item_ids
		}
	elif raw_mechanic_state is Dictionary:
		normalized_mechanic_state = (raw_mechanic_state as Dictionary).duplicate(true)

	if mechanic_type.is_empty() and (
		run_index > 1 or not normalized_mechanic_state.is_empty()
	):
		mechanic_type = LevelMechanicTypes.PLATE_SORT

	if normalized_mechanic_state.is_empty() and run_index <= 1:
		return {}

	var normalized_level_state: Dictionary = {
		_global_state.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		_global_state.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		_global_state.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}

	if mechanic_type == LevelMechanicTypes.PLATE_SORT:
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
		var raw_track_levels: Variant = partial_level_states.get(track_key, {})
		if not raw_track_levels is Dictionary:
			partial_level_states[track_key] = {}
			continue

		var pending_track_levels: Dictionary = {}
		var max_level_number: int = _global_state.get_track_level_count(track_key)

		for raw_key in raw_track_levels.keys():
			var level_key := str(raw_key).strip_edges()
			if not level_key.is_valid_int():
				continue

			var level_number := clampi(int(level_key), 1, max_level_number)
			if _global_state.is_level_completed(track_key, level_number):
				continue

			var normalized_level_state := normalize_level_state(
				raw_track_levels[raw_key]
			)
			if not normalized_level_state.is_empty():
				pending_track_levels[str(level_number)] = normalized_level_state

		partial_level_states[track_key] = pending_track_levels


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
