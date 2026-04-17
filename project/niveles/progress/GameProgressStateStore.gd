extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")
const GameStreakTracker := preload("res://niveles/progress/GameStreakTracker.gd")

const BOOK_LEVEL_COMPLETED_KEY := "completed"
const DEFAULT_PROGRESS_LABEL := "Tu progreso"
const PLATE_SORT_MECHANIC_TYPE := "plate_sort"

const STREAK_SYSTEM_KEY := "streak"

var _global_state
var _content
var _campaign_progress_by_track: Dictionary = {}
var _partial_level_state_by_track: Dictionary = {}
var _progress_system_state_by_key: Dictionary = {}


func _init(global_state, content_catalog) -> void:
	_global_state = global_state
	_content = content_catalog
	reset_progress()


func get_campaign_progress_for_track(track_key: String) -> Dictionary:
	var resolved_track_key: String = _resolve_track_key(track_key)
	if resolved_track_key.is_empty():
		return {}

	if not _campaign_progress_by_track.has(resolved_track_key):
		_campaign_progress_by_track[resolved_track_key] = (
			_content.build_default_track_progress_for_track(resolved_track_key)
		)

	var raw_track_progress: Variant = _campaign_progress_by_track.get(
		resolved_track_key,
		{}
	)
	return raw_track_progress if raw_track_progress is Dictionary else {}


func mark_level_completed(track_key: String, level_number: int) -> void:
	var resolved_track_key: String = _resolve_track_key(track_key)
	var resolved_level_number: int = _resolve_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return

	var track_progress: Dictionary = get_campaign_progress_for_track(resolved_track_key)
	var raw_level_progress: Variant = track_progress.get(resolved_level_number, {})
	if not raw_level_progress is Dictionary:
		return

	var level_progress: Dictionary = raw_level_progress
	level_progress[BOOK_LEVEL_COMPLETED_KEY] = true
	track_progress[resolved_level_number] = level_progress


func is_level_unlocked(track_key: String, level_number: int) -> bool:
	var resolved_track_key: String = _resolve_track_key(track_key)
	if resolved_track_key.is_empty():
		return level_number <= 1

	var unlocked_level_number: int = clampi(
		level_number,
		1,
		_get_track_level_count(resolved_track_key)
	)
	if unlocked_level_number <= 1:
		return true
	return is_level_completed(resolved_track_key, unlocked_level_number - 1)


func is_level_completed(track_key: String, level_number: int) -> bool:
	var resolved_track_key: String = _resolve_track_key(track_key)
	var resolved_level_number: int = _resolve_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return false

	var track_progress: Dictionary = get_campaign_progress_for_track(resolved_track_key)
	var raw_level_progress: Variant = track_progress.get(resolved_level_number, {})
	if not raw_level_progress is Dictionary:
		return false

	return bool(raw_level_progress.get(BOOK_LEVEL_COMPLETED_KEY, false))


func reset_progress() -> void:
	_campaign_progress_by_track = _content.build_default_track_progress_state()
	_partial_level_state_by_track = _build_empty_partial_level_state_map()
	_progress_system_state_by_key = {}
	_global_state.set_current_level_number(1)


func export_progress() -> Dictionary:
	var progress_snapshot: Dictionary = {
		"current_level": _global_state.get_current_level_number()
	}

	for track_key in GameTrackCatalog.TRACK_ORDER:
		progress_snapshot[track_key] = _build_completed_level_flags_for_track(track_key)

	progress_snapshot[GameProgressKeys.PARTIAL_LEVEL_STATES_KEY] = (
		_export_partial_level_states(
			_partial_level_state_by_track
		)
	)
	progress_snapshot[GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY] = (
		_normalize_progress_system_states(
			_progress_system_state_by_key
		)
	)
	return progress_snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return

	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))

	for track_key in GameTrackCatalog.TRACK_ORDER:
		_restore_completed_level_flags_for_track(track_key, progress_snapshot.get(track_key, []))

	_partial_level_state_by_track = _normalize_partial_level_states(
		progress_snapshot.get(GameProgressKeys.PARTIAL_LEVEL_STATES_KEY, {})
	)
	_remove_completed_partial_states(_partial_level_state_by_track)
	_progress_system_state_by_key = _normalize_progress_system_states(
		progress_snapshot.get(GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY, {})
	)


func get_progress_summary() -> Dictionary:
	var progress_summary: Dictionary = {
		"total": 0,
		"max_total": _get_total_level_count()
	}

	for track_key in GameTrackCatalog.TRACK_ORDER:
		var completed_levels_for_track: int = 0
		var level_count: int = _get_track_level_count(track_key)
		for level_number in range(1, level_count + 1):
			if is_level_completed(track_key, level_number):
				completed_levels_for_track += 1

		progress_summary[track_key] = completed_levels_for_track
		progress_summary["total"] = (
			int(progress_summary.get("total", 0))
			+ completed_levels_for_track
		)

	return progress_summary


func format_progress_summary_text(summary: Dictionary = {}) -> String:
	var summary_by_track := summary if not summary.is_empty() else get_progress_summary()
	var summary_lines: Array[String] = []
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		if track_key.is_empty():
			continue

		var level_count: int = _get_track_level_count(track_key)
		if level_count <= 0:
			continue

		var completed_levels: int = int(summary_by_track.get(track_key, 0))
		var visible_levels: int = min(level_count, completed_levels + 1)
		var summary_label := str(
			track_definition.get(
				"summary_label",
				track_definition.get("label", DEFAULT_PROGRESS_LABEL)
			)
		)
		summary_lines.append("%s %d/%d" % [summary_label, visible_levels, level_count])
	return "\n".join(summary_lines)


func get_streak_state() -> Dictionary:
	return GameStreakTracker.read(get_progress_system_state(STREAK_SYSTEM_KEY))


func get_streak_view_model() -> Dictionary:
	return GameStreakTracker.view_model(get_streak_state())


func record_streak_activity(
	activity_type: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var updated: Dictionary = GameStreakTracker.record(get_streak_state(), activity_type, metadata)
	set_progress_system_state(STREAK_SYSTEM_KEY, updated)
	return updated


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var resolved_track_key: String = _resolve_track_key(track_key)
	var resolved_level_number: int = _resolve_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return {}

	var raw_track_level_states: Variant = _partial_level_state_by_track.get(
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
	var resolved_track_key: String = _resolve_track_key(track_key)
	var resolved_level_number: int = _resolve_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return

	var raw_track_level_states: Variant = _partial_level_state_by_track.get(
		resolved_track_key,
		{}
	)
	var stored_track_level_states: Dictionary = (
		raw_track_level_states if raw_track_level_states is Dictionary else {}
	)
	var level_state_key: String = str(resolved_level_number)

	if is_level_completed(resolved_track_key, resolved_level_number):
		stored_track_level_states.erase(level_state_key)
		_partial_level_state_by_track[resolved_track_key] = stored_track_level_states
		return

	var level_state_to_store: Dictionary = _normalize_level_state(state)
	if level_state_to_store.is_empty():
		stored_track_level_states.erase(level_state_key)
	else:
		stored_track_level_states[level_state_key] = level_state_to_store

	_partial_level_state_by_track[resolved_track_key] = stored_track_level_states


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var resolved_track_key: String = _resolve_track_key(track_key)
	var resolved_level_number: int = _resolve_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return

	var raw_track_level_states: Variant = _partial_level_state_by_track.get(
		resolved_track_key,
		{}
	)
	var stored_track_level_states: Dictionary = (
		raw_track_level_states if raw_track_level_states is Dictionary else {}
	)
	stored_track_level_states.erase(str(resolved_level_number))
	_partial_level_state_by_track[resolved_track_key] = stored_track_level_states


func get_progress_system_state(system_key: String) -> Dictionary:
	var resolved_system_key: String = system_key.strip_edges()
	if resolved_system_key.is_empty():
		return {}
	if not _progress_system_state_by_key.has(resolved_system_key):
		return {}
	return _progress_system_state_by_key[resolved_system_key].duplicate(true)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	var resolved_system_key: String = system_key.strip_edges()
	if resolved_system_key.is_empty():
		return
	if system_state.is_empty():
		_progress_system_state_by_key.erase(resolved_system_key)
		return
	_progress_system_state_by_key[resolved_system_key] = (
		system_state.duplicate(true)
	)


func clear_progress_system_state(system_key: String) -> void:
	var resolved_system_key: String = system_key.strip_edges()
	if resolved_system_key.is_empty():
		return
	_progress_system_state_by_key.erase(resolved_system_key)


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

	for track_key in GameTrackCatalog.TRACK_ORDER:
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

	for track_key in GameTrackCatalog.TRACK_ORDER:
		normalized_states_by_track[track_key] = _normalize_track_level_states(
			stored_states_by_track.get(track_key, {}),
			track_key,
			false
		)

	return normalized_states_by_track


func _normalize_level_state(raw_level_state: Variant) -> Dictionary:
	if not raw_level_state is Dictionary:
		return {}

	var state: Dictionary = raw_level_state
	var run_index: int = max(1, int(state.get(GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)))
	var mechanic_type: String = str(state.get(GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, "")).strip_edges()
	var raw_mechanic_state: Variant = state.get(GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY, {})

	var mechanic_state: Dictionary = {}
	if mechanic_type.is_empty() or mechanic_type == PLATE_SORT_MECHANIC_TYPE:
		mechanic_state = _normalize_plate_sort_mechanic(state, raw_mechanic_state)
	elif raw_mechanic_state is Dictionary:
		mechanic_state = (raw_mechanic_state as Dictionary).duplicate(true)

	if mechanic_type.is_empty() and (run_index > 1 or not mechanic_state.is_empty()):
		mechanic_type = PLATE_SORT_MECHANIC_TYPE

	if mechanic_state.is_empty() and run_index <= 1:
		return {}

	return {
		GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY: mechanic_state,
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: mechanic_state.get(GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY, []),
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: mechanic_state.get(GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	}


func _normalize_plate_sort_mechanic(state: Dictionary, raw_mechanic_state: Variant) -> Dictionary:
	# Si el mechanic_state tiene datos usarlo directamente; si no, leer desde la raíz (legado).
	var plate_sort_state: Dictionary = {}
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		plate_sort_state = raw_mechanic_state
	else:
		plate_sort_state = {
			GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: state.get(GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY, []),
			GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: state.get(GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
		}

	var items: Array = _normalize_plate_sort_items(plate_sort_state)
	var valid_positive_ids: Dictionary = {}
	for item in items:
		if bool(item.get(GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)):
			valid_positive_ids[str(item.get(GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY, ""))] = true

	return {
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: items,
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: _normalize_placed_ids(plate_sort_state, valid_positive_ids)
	}


func _normalize_plate_sort_items(plate_sort_state: Dictionary) -> Array:
	var items: Array = []
	var raw_items: Variant = plate_sort_state.get(GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY, [])
	if not raw_items is Array:
		return items
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			continue
		var item_path: String = str(raw_item.get(GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY, "")).strip_edges()
		var instance_id: String = str(raw_item.get(GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue
		items.append({
			GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
			GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
			GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(raw_item.get(GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY, false))
		})
	return items


func _normalize_placed_ids(plate_sort_state: Dictionary, valid_positive_ids: Dictionary) -> Array:
	var result: Array = []
	var raw_ids: Variant = plate_sort_state.get(GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	if not raw_ids is Array:
		return result
	for raw_id in raw_ids:
		var item_id: String = str(raw_id).strip_edges()
		if item_id.is_empty() or result.has(item_id) or not valid_positive_ids.has(item_id):
			continue
		result.append(item_id)
	return result


func _remove_completed_partial_states(partial_level_states: Dictionary) -> void:
	for track_key in GameTrackCatalog.TRACK_ORDER:
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

	var max_level_number: int = _get_track_level_count(track_key)
	var track_level_states: Dictionary = raw_track_level_states

	for raw_level_key in track_level_states.keys():
		var level_key: String = str(raw_level_key).strip_edges()
		if not level_key.is_valid_int():
			continue

		var level_number: int = clampi(int(level_key), 1, max_level_number)
		if skip_completed_levels and is_level_completed(track_key, level_number):
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
	var level_count: int = _get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		completed_level_flags.append(is_level_completed(track_key, level_number))
	return completed_level_flags


func _restore_completed_level_flags_for_track(track_key: String, stored_flags: Variant) -> void:
	if not stored_flags is Array:
		return

	var track_progress: Dictionary = get_campaign_progress_for_track(track_key)
	var level_count: int = _get_track_level_count(track_key)
	var stored_completion_flags: Array = stored_flags

	for level_index in range(min(stored_completion_flags.size(), level_count)):
		var level_number: int = level_index + 1
		var stored_level_progress: Variant = track_progress.get(level_number, {})
		if not stored_level_progress is Dictionary:
			continue

		var level_progress_entry: Dictionary = stored_level_progress
		level_progress_entry[BOOK_LEVEL_COMPLETED_KEY] = bool(
			stored_completion_flags[level_index]
		)
		track_progress[level_number] = level_progress_entry


func _build_empty_partial_level_state_map() -> Dictionary:
	var empty_partial_states_by_track: Dictionary = {}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		empty_partial_states_by_track[track_key] = {}
	return empty_partial_states_by_track


func _resolve_track_key(track_key: String) -> String:
	var resolved_track_key: String = track_key.strip_edges()
	if resolved_track_key.is_empty() or not GameTrackCatalog.has_track(resolved_track_key):
		return ""
	return resolved_track_key


func _resolve_level_number(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return 0

	var max_level_number: int = _get_track_level_count(track_key)
	if max_level_number <= 0:
		return 0

	return clampi(level_number, 1, max_level_number)


func _get_track_level_count(track_key: String) -> int:
	return _content.get_track_level_count(
		track_key,
		GameTrackCatalog.get_track_level_count(
			track_key,
			GameTrackCatalog.DEFAULT_LEVEL_COUNT
		)
	)


func _get_total_level_count() -> int:
	return _content.get_total_level_count(GameTrackCatalog.get_total_level_count())
