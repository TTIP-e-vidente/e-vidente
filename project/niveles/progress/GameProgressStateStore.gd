extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")

const PLATE_SORT_MECHANIC_TYPE := "plate_sort"

var _global_state


func _init(global_state):
	_global_state = global_state


func build_empty_partial_level_state_map() -> Dictionary:
	var empty_partial_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		empty_partial_states_by_track[track_key] = {}
	return empty_partial_states_by_track


func reset_progress() -> void:
	_global_state.campaign_progress_by_track = _global_state.build_default_campaign_progress_state()
	_global_state.partial_level_state_by_track = build_empty_partial_level_state_map()
	_global_state.progress_system_state_by_key = {}
	_global_state.set_current_level_number(1)


func export_progress() -> Dictionary:
	var progress_snapshot: Dictionary = {
		"current_level": _global_state.get_current_level_number()
	}

	for track_key in _global_state.TRACK_KEYS:
		progress_snapshot[track_key] = _build_completed_level_flags_for_track(track_key)

	progress_snapshot[GameProgressKeys.PARTIAL_LEVEL_STATES_KEY] = (
		_export_partial_level_states(
			_global_state.partial_level_state_by_track
		)
	)
	progress_snapshot[GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY] = (
		_normalize_progress_system_states(
			_global_state.progress_system_state_by_key
		)
	)
	return progress_snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return

	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))

	for track_key in _global_state.TRACK_KEYS:
		_restore_completed_level_flags_for_track(track_key, progress_snapshot.get(track_key, []))

	_global_state.partial_level_state_by_track = _normalize_partial_level_states(
		progress_snapshot.get(GameProgressKeys.PARTIAL_LEVEL_STATES_KEY, {})
	)
	_remove_completed_partial_states(_global_state.partial_level_state_by_track)
	_global_state.progress_system_state_by_key = _normalize_progress_system_states(
		progress_snapshot.get(GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY, {})
	)


func get_progress_summary() -> Dictionary:
	var progress_summary: Dictionary = {
		"total": 0,
		"max_total": _global_state.get_total_level_count()
	}

	for track_key in _global_state.TRACK_KEYS:
		var completed_levels_for_track: int = 0
		var level_count: int = _global_state.get_track_level_count(track_key)
		for level_number in range(1, level_count + 1):
			if _global_state.is_level_completed(track_key, level_number):
				completed_levels_for_track += 1

		progress_summary[track_key] = completed_levels_for_track
		progress_summary["total"] = (
			int(progress_summary.get("total", 0))
			+ completed_levels_for_track
		)

	return progress_summary


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var resolved_track_key: String = track_key.strip_edges()
	if resolved_track_key.is_empty() or not GameTrackCatalog.has_track(resolved_track_key):
		return {}

	var max_level_number: int = _global_state.get_track_level_count(resolved_track_key)
	if max_level_number <= 0:
		return {}

	var resolved_level_number: int = clampi(level_number, 1, max_level_number)
	if resolved_level_number <= 0:
		return {}

	var raw_track_level_states: Variant = _global_state.partial_level_state_by_track.get(
		resolved_track_key,
		{}
	)
	var stored_track_level_states: Dictionary = (
		raw_track_level_states if raw_track_level_states is Dictionary else {}
	)
	return _normalize_level_state(
		stored_track_level_states.get(str(resolved_level_number), {})
	)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var resolved_track_key: String = track_key.strip_edges()
	if resolved_track_key.is_empty() or not GameTrackCatalog.has_track(resolved_track_key):
		return

	var max_level_number: int = _global_state.get_track_level_count(resolved_track_key)
	if max_level_number <= 0:
		return

	var resolved_level_number: int = clampi(level_number, 1, max_level_number)
	if resolved_level_number <= 0:
		return

	var raw_track_level_states: Variant = _global_state.partial_level_state_by_track.get(
		resolved_track_key,
		{}
	)
	var stored_track_level_states: Dictionary = (
		raw_track_level_states if raw_track_level_states is Dictionary else {}
	)
	var level_state_key: String = str(resolved_level_number)

	if _global_state.is_level_completed(resolved_track_key, resolved_level_number):
		stored_track_level_states.erase(level_state_key)
		_global_state.partial_level_state_by_track[resolved_track_key] = stored_track_level_states
		return

	var level_state_to_store: Dictionary = _normalize_level_state(state)
	if level_state_to_store.is_empty():
		stored_track_level_states.erase(level_state_key)
	else:
		stored_track_level_states[level_state_key] = level_state_to_store

	_global_state.partial_level_state_by_track[resolved_track_key] = stored_track_level_states


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var resolved_track_key: String = track_key.strip_edges()
	if resolved_track_key.is_empty() or not GameTrackCatalog.has_track(resolved_track_key):
		return

	var max_level_number: int = _global_state.get_track_level_count(resolved_track_key)
	if max_level_number <= 0:
		return

	var resolved_level_number: int = clampi(level_number, 1, max_level_number)
	if resolved_level_number <= 0:
		return

	var raw_track_level_states: Variant = _global_state.partial_level_state_by_track.get(
		resolved_track_key,
		{}
	)
	var stored_track_level_states: Dictionary = (
		raw_track_level_states if raw_track_level_states is Dictionary else {}
	)
	stored_track_level_states.erase(str(resolved_level_number))
	_global_state.partial_level_state_by_track[resolved_track_key] = stored_track_level_states


func get_progress_system_state(system_key: String) -> Dictionary:
	var resolved_system_key: String = system_key.strip_edges()
	if resolved_system_key.is_empty():
		return {}
	if not _global_state.progress_system_state_by_key.has(resolved_system_key):
		return {}
	return _global_state.progress_system_state_by_key[resolved_system_key].duplicate(true)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	var resolved_system_key: String = system_key.strip_edges()
	if resolved_system_key.is_empty():
		return
	if system_state.is_empty():
		_global_state.progress_system_state_by_key.erase(resolved_system_key)
		return
	_global_state.progress_system_state_by_key[resolved_system_key] = (
		system_state.duplicate(true)
	)


func clear_progress_system_state(system_key: String) -> void:
	var resolved_system_key: String = system_key.strip_edges()
	if resolved_system_key.is_empty():
		return
	_global_state.progress_system_state_by_key.erase(resolved_system_key)


func _normalize_progress_system_states(raw_system_states: Variant) -> Dictionary:
	if not raw_system_states is Dictionary:
		return {}

	var normalized_states_by_system: Dictionary = {}
	for raw_system_key in raw_system_states.keys():
		var resolved_system_key: String = str(raw_system_key).strip_edges()
		if resolved_system_key.is_empty():
			continue

		var stored_system_state: Variant = raw_system_states.get(raw_system_key, {})
		if not stored_system_state is Dictionary:
			continue

		normalized_states_by_system[resolved_system_key] = (
			stored_system_state as Dictionary
		).duplicate(true)

	return normalized_states_by_system


func _export_partial_level_states(partial_level_states: Dictionary) -> Dictionary:
	var exported_states_by_track: Dictionary = {}

	for track_key in _global_state.TRACK_KEYS:
		var raw_track_level_states: Variant = partial_level_states.get(track_key, {})
		if not raw_track_level_states is Dictionary:
			continue

		var exported_track_level_states: Dictionary = {}
		var track_level_states: Dictionary = raw_track_level_states
		for raw_level_key in track_level_states.keys():
			var level_key: String = str(raw_level_key).strip_edges()
			if level_key.is_empty():
				continue

			var normalized_level_state: Dictionary = _normalize_level_state(
				track_level_states[raw_level_key]
			)
			if normalized_level_state.is_empty():
				continue

			exported_track_level_states[level_key] = normalized_level_state

		if exported_track_level_states.is_empty():
			continue

		exported_states_by_track[track_key] = exported_track_level_states

	return exported_states_by_track


func _normalize_partial_level_states(raw_states: Variant) -> Dictionary:
	var stored_states_by_track: Dictionary = raw_states if raw_states is Dictionary else {}
	var normalized_states_by_track: Dictionary = {}

	for track_key in _global_state.TRACK_KEYS:
		normalized_states_by_track[track_key] = _normalize_track_level_states(
			stored_states_by_track.get(track_key, {}),
			track_key,
			false
		)

	return normalized_states_by_track


func _normalize_level_state(raw_level_state: Variant) -> Dictionary:
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

	if mechanic_type.is_empty() or mechanic_type == PLATE_SORT_MECHANIC_TYPE:
		var saved_plate_sort_state: Dictionary = {}
		if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
			saved_plate_sort_state = raw_mechanic_state
		else:
			saved_plate_sort_state = {
				GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: stored_level_state.get(
					GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY,
					[]
				),
				GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: stored_level_state.get(
					GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
					[]
				)
			}

		var saved_item_entries: Array = []
		var positive_item_ids_by_instance: Dictionary = {}
		var raw_saved_items: Variant = saved_plate_sort_state.get(
			GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		)
		if raw_saved_items is Array:
			for raw_saved_item in raw_saved_items:
				if not raw_saved_item is Dictionary:
					continue

				var item_path: String = str(
					raw_saved_item.get(GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
				).strip_edges()
				var instance_id: String = str(
					raw_saved_item.get(GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
				).strip_edges()
				if item_path.is_empty() or instance_id.is_empty():
					continue

				var saved_item_entry: Dictionary = {
					GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
					GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
					GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(
						raw_saved_item.get(
							GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY,
							false
						)
					)
				}
				saved_item_entries.append(saved_item_entry)
				if bool(
					saved_item_entry.get(
						GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY,
						false
					)
				):
					positive_item_ids_by_instance[instance_id] = true

		var placed_positive_item_ids: Array = []
		var raw_placed_item_ids: Variant = saved_plate_sort_state.get(
			GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
		if raw_placed_item_ids is Array:
			for raw_item_id in raw_placed_item_ids:
				var item_id: String = str(raw_item_id).strip_edges()
				if item_id.is_empty() or placed_positive_item_ids.has(item_id):
					continue
				if not positive_item_ids_by_instance.has(item_id):
					continue

				placed_positive_item_ids.append(item_id)

		normalized_mechanic_state = {
			GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: saved_item_entries,
			GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
		}
	elif raw_mechanic_state is Dictionary:
		normalized_mechanic_state = (raw_mechanic_state as Dictionary).duplicate(true)

	var has_saved_progress: bool = run_index > 1 or not normalized_mechanic_state.is_empty()
	if mechanic_type.is_empty() and has_saved_progress:
		mechanic_type = PLATE_SORT_MECHANIC_TYPE

	if normalized_mechanic_state.is_empty() and run_index <= 1:
		return {}

	var normalized_level_state: Dictionary = {
		GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY: normalized_mechanic_state
	}

	if mechanic_type == PLATE_SORT_MECHANIC_TYPE:
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


func _remove_completed_partial_states(partial_level_states: Dictionary) -> void:
	for track_key in _global_state.TRACK_KEYS:
		partial_level_states[track_key] = _normalize_track_level_states(
			partial_level_states.get(track_key, {}),
			track_key,
			true
		)


func _normalize_track_level_states(
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

		var normalized_level_state: Dictionary = _normalize_level_state(
			track_level_states[raw_level_key]
		)
		if normalized_level_state.is_empty():
			continue

		normalized_track_level_states[str(level_number)] = normalized_level_state

	return normalized_track_level_states


func _build_completed_level_flags_for_track(track_key: String) -> Array:
	var completed_level_flags: Array = []
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		completed_level_flags.append(_global_state.is_level_completed(track_key, level_number))
	return completed_level_flags


func _restore_completed_level_flags_for_track(track_key: String, stored_flags: Variant) -> void:
	if not stored_flags is Array:
		return

	var track_progress: Dictionary = _global_state.get_campaign_progress_for_track(track_key)
	var level_count: int = _global_state.get_track_level_count(track_key)
	var stored_completion_flags: Array = stored_flags

	for level_index in range(min(stored_completion_flags.size(), level_count)):
		var level_number: int = level_index + 1
		var stored_level_progress: Variant = track_progress.get(level_number, {})
		if not stored_level_progress is Dictionary:
			continue

		var level_progress_entry: Dictionary = stored_level_progress
		level_progress_entry[_global_state.BOOK_LEVEL_COMPLETED_KEY] = bool(
			stored_completion_flags[level_index]
		)
		track_progress[level_number] = level_progress_entry

