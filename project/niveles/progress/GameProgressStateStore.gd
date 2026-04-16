extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")

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
	return _read_streak_state(get_progress_system_state(STREAK_SYSTEM_KEY))


func get_streak_view_model() -> Dictionary:
	var streak_state: Dictionary = get_streak_state()
	var current_count: int = int(streak_state.get("current_count", 0))
	var best_count: int = int(streak_state.get("best_count", 0))
	var last_activity_day: String = str(streak_state.get("last_activity_day", ""))
	if current_count <= 0:
		return {
			"current_count": 0,
			"best_count": best_count,
			"status_key": "inactive",
			"status_title": "Sin racha activa",
			"status_detail": "Completa una actividad para iniciar la racha."
		}

	if last_activity_day == Time.get_date_string_from_system(false):
		return {
			"current_count": current_count,
			"best_count": best_count,
			"status_key": "active_today",
			"status_title": "Racha activa",
			"status_detail": "Hoy ya registraste una actividad."
		}

	return {
		"current_count": current_count,
		"best_count": best_count,
		"status_key": "pending_today",
		"status_title": "Racha pendiente hoy",
		"status_detail": "Tu racha sigue viva, pero todavia falta sostenerla hoy."
	}


func build_streak_feedback_event(
	previous_state: Dictionary,
	next_state: Dictionary = {}
) -> Dictionary:
	var normalized_previous_state: Dictionary = _read_streak_state(previous_state)
	var normalized_next_state: Dictionary = get_streak_state()
	if not next_state.is_empty():
		normalized_next_state = _read_streak_state(next_state)

	var today_day_key: String = Time.get_date_string_from_system(false)
	var previous_activity_day: String = str(
		normalized_previous_state.get("last_activity_day", "")
	).strip_edges()
	if previous_activity_day == today_day_key:
		return {"should_show": false}

	var next_activity_day: String = str(
		normalized_next_state.get("last_activity_day", "")
	).strip_edges()
	if next_activity_day != today_day_key:
		return {"should_show": false}

	var current_count: int = int(normalized_next_state.get("current_count", 0))
	if current_count <= 1:
		return {
			"should_show": true,
			"feedback_key": "activated",
			"title": "Racha activada",
			"message": "Hoy empezaste una racha de 1 dia.",
			"current_count": 1,
			"best_count": int(normalized_next_state.get("best_count", 0))
		}

	return {
		"should_show": true,
		"feedback_key": "sustained",
		"title": "Hoy sostuviste tu racha",
		"message": "Vas %d %s seguidos." % [
			current_count,
			"dia" if current_count == 1 else "dias"
		],
		"current_count": current_count,
		"best_count": int(normalized_next_state.get("best_count", 0))
	}


func record_streak_activity(
	activity_type: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var streak_state: Dictionary = get_streak_state()
	var today_day_key: String = Time.get_date_string_from_system(false)
	var last_activity_day: String = str(streak_state.get("last_activity_day", ""))
	var current_count: int = 1

	if last_activity_day == today_day_key:
		current_count = int(streak_state.get("current_count", 0))
	elif not last_activity_day.is_empty():
		var last_activity_day_unix: int = int(
			Time.get_unix_time_from_datetime_string(last_activity_day)
		)
		var today_day_unix: int = int(
			Time.get_unix_time_from_datetime_string(today_day_key)
		)
		var day_difference: int = int(
			(today_day_unix - last_activity_day_unix) / 86400.0
		)
		if day_difference == 1:
			current_count = int(streak_state.get("current_count", 0)) + 1

	var updated_streak_state: Dictionary = {
		"current_count": current_count,
		"best_count": max(int(streak_state.get("best_count", 0)), current_count),
		"last_activity_day": today_day_key,
		"last_activity_type": (
			"activity"
			if activity_type.strip_edges().is_empty()
			else activity_type.strip_edges()
		),
		"last_track_key": str(metadata.get("track_key", "")).strip_edges()
	}
	set_progress_system_state(STREAK_SYSTEM_KEY, updated_streak_state)
	return updated_streak_state


func clear_streak_state() -> void:
	clear_progress_system_state(STREAK_SYSTEM_KEY)


func has_streak_activity_today() -> bool:
	return str(
		get_streak_state().get("last_activity_day", "")
	).strip_edges() == Time.get_date_string_from_system(false)


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


func _read_streak_state(raw_state: Variant) -> Dictionary:
	var streak_state: Dictionary = {
		"current_count": 0,
		"best_count": 0,
		"last_activity_day": "",
		"last_activity_type": "",
		"last_track_key": ""
	}
	if not raw_state is Dictionary:
		return streak_state

	var stored_streak_state: Dictionary = raw_state
	var current_count: int = max(0, int(stored_streak_state.get("current_count", 0)))
	var best_count: int = max(current_count, int(stored_streak_state.get("best_count", 0)))
	var last_activity_day: String = str(
		stored_streak_state.get("last_activity_day", "")
	).strip_edges()
	if not last_activity_day.is_empty():
		var last_activity_day_unix: int = int(
			Time.get_unix_time_from_datetime_string(last_activity_day)
		)
		if Time.get_date_string_from_unix_time(last_activity_day_unix) != last_activity_day:
			last_activity_day = ""
			current_count = 0
	else:
		current_count = 0

	streak_state["current_count"] = current_count
	streak_state["best_count"] = best_count
	streak_state["last_activity_day"] = last_activity_day
	if not last_activity_day.is_empty():
		streak_state["last_activity_type"] = str(
			stored_streak_state.get("last_activity_type", "")
		).strip_edges()
		streak_state["last_track_key"] = str(
			stored_streak_state.get("last_track_key", "")
		).strip_edges()
	return streak_state

