extends RefCounted

const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")
const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

var _global_state


func _init(global_state):
	_global_state = global_state


func export_track_states(partial_level_states: Dictionary) -> Dictionary:
	var exported_states_by_track: Dictionary = {}

	for track_key in _global_state.TRACK_KEYS:
		var exported_track_level_states: Dictionary = _export_valid_level_states_for_track(
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
		normalized_states_by_track[track_key] = _normalize_level_states_for_track(
			raw_states_by_track.get(track_key, {}),
			track_key,
			false
		)

	return normalized_states_by_track


func normalize_level_state(raw_level_state: Variant) -> Dictionary:
	if not raw_level_state is Dictionary:
		return {}

	var stored_level_state: Dictionary = raw_level_state
	var run_index: int = max(
		1,
		int(stored_level_state.get(GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY, 1))
	)
	var mechanic_type: String = str(
		stored_level_state.get(GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")
	).strip_edges()
	var raw_mechanic_state: Variant = stored_level_state.get(
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	var normalized_mechanic_state: Dictionary = {}

	if mechanic_type.is_empty() or mechanic_type == LevelMechanicTypes.PLATE_SORT:
		normalized_mechanic_state = _normalize_plate_sort_level_state(
			stored_level_state,
			raw_mechanic_state
		)
	elif raw_mechanic_state is Dictionary:
		normalized_mechanic_state = (raw_mechanic_state as Dictionary).duplicate(true)

	var has_saved_progress: bool = run_index > 1 or not normalized_mechanic_state.is_empty()
	if mechanic_type.is_empty() and has_saved_progress:
		mechanic_type = LevelMechanicTypes.PLATE_SORT

	if normalized_mechanic_state.is_empty():
		if run_index <= 1:
			return {}

	var normalized_level_state: Dictionary = {
		GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}

	if mechanic_type == LevelMechanicTypes.PLATE_SORT:
		normalized_level_state[GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY] = (
			normalized_mechanic_state.get(GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY, [])
		)
		normalized_level_state[GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = (
			normalized_mechanic_state.get(
				GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
				[]
			)
		)

	return normalized_level_state


func _normalize_plate_sort_level_state(
	stored_level_state: Dictionary,
	raw_mechanic_state: Variant
) -> Dictionary:
	var plate_sort_state_to_normalize: Dictionary = {}
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		plate_sort_state_to_normalize = raw_mechanic_state
	else:
		plate_sort_state_to_normalize = {
			GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: stored_level_state.get(
				GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY,
				[]
			),
			GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: stored_level_state.get(
				GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
				[]
			)
		}

	var normalized_item_entries: Array = []
	var valid_positive_item_ids: Dictionary = {}
	var raw_saved_items: Variant = plate_sort_state_to_normalize.get(
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY,
		[]
	)
	if raw_saved_items is Array:
		for raw_saved_item in raw_saved_items:
			var normalized_saved_item: Dictionary = _normalize_plate_sort_item_entry(
				raw_saved_item
			)
			if normalized_saved_item.is_empty():
				continue

			normalized_item_entries.append(normalized_saved_item)
			if bool(
				normalized_saved_item.get(
					GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY,
					false
				)
			):
				var instance_id: String = str(
					normalized_saved_item.get(
						GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY,
						""
					)
				)
				valid_positive_item_ids[instance_id] = true

	var normalized_placed_item_ids: Array = []
	var raw_placed_item_ids: Variant = plate_sort_state_to_normalize.get(
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	if raw_placed_item_ids is Array:
		for raw_item_id in raw_placed_item_ids:
			var item_id: String = str(raw_item_id).strip_edges()
			if item_id.is_empty() or normalized_placed_item_ids.has(item_id):
				continue
			if not valid_positive_item_ids.has(item_id):
				continue

			normalized_placed_item_ids.append(item_id)

	return {
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: normalized_item_entries,
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_item_ids
	}


func remove_completed_states(partial_level_states: Dictionary) -> void:
	for track_key in _global_state.TRACK_KEYS:
		partial_level_states[track_key] = _normalize_level_states_for_track(
			partial_level_states.get(track_key, {}),
			track_key,
			true
		)


func _normalize_plate_sort_item_entry(raw_saved_item: Variant) -> Dictionary:
	if not raw_saved_item is Dictionary:
		return {}

	var item_path: String = str(
		raw_saved_item.get(GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		raw_saved_item.get(GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return {}

	return {
		GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
		GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
		GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(
			raw_saved_item.get(GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
		)
	}


func _export_valid_level_states_for_track(raw_track_level_states: Variant) -> Dictionary:
	var exported_track_level_states: Dictionary = {}
	if not raw_track_level_states is Dictionary:
		return exported_track_level_states

	var track_level_states: Dictionary = raw_track_level_states
	for raw_level_key in track_level_states.keys():
		var level_key: String = str(raw_level_key).strip_edges()
		if level_key.is_empty():
			continue

		var normalized_level_state: Dictionary = normalize_level_state(
			track_level_states[raw_level_key]
		)
		if normalized_level_state.is_empty():
			continue

		exported_track_level_states[level_key] = normalized_level_state

	return exported_track_level_states


func _normalize_level_states_for_track(
	raw_track_level_states: Variant,
	track_key: String,
	skip_completed_levels: bool
) -> Dictionary:
	var normalized_track_level_states: Dictionary = {}
	if not raw_track_level_states is Dictionary:
		return normalized_track_level_states

	var max_level_number: int = _global_state.get_track_level_count(track_key)
	var track_level_states: Dictionary = raw_track_level_states

	for raw_level_key in track_level_states.keys():
		var level_key: String = str(raw_level_key).strip_edges()
		if not level_key.is_valid_int():
			continue

		var level_number: int = clampi(int(level_key), 1, max_level_number)
		if skip_completed_levels and _global_state.is_level_completed(track_key, level_number):
			continue

		var normalized_level_state: Dictionary = normalize_level_state(
			track_level_states[raw_level_key]
		)
		if normalized_level_state.is_empty():
			continue

		normalized_track_level_states[str(level_number)] = normalized_level_state

	return normalized_track_level_states
