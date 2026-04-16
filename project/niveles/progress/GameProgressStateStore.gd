extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")
const GamePartialLevelStateCodecScript := preload(
	"res://niveles/progress/GamePartialLevelStateCodec.gd"
)

var _global_state
var _level_state_codec


func _init(global_state):
	_global_state = global_state
	_level_state_codec = GamePartialLevelStateCodecScript.new(global_state)


func build_empty_partial_level_state_map() -> Dictionary:
	var empty_level_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		empty_level_states_by_track[track_key] = {}
	return empty_level_states_by_track


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
		_level_state_codec.export_track_states(
			_global_state.partial_level_state_by_track
		)
	)
	progress_snapshot[GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY] = _normalize_system_states(
		_global_state.progress_system_state_by_key
	)
	return progress_snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return

	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))

	for track_key in _global_state.TRACK_KEYS:
		_restore_completed_level_flags_for_track(track_key, progress_snapshot.get(track_key, []))

	_global_state.partial_level_state_by_track = _level_state_codec.normalize_track_states(
		progress_snapshot.get(GameProgressKeys.PARTIAL_LEVEL_STATES_KEY, {})
	)
	_level_state_codec.remove_completed_states(
		_global_state.partial_level_state_by_track
	)
	_global_state.progress_system_state_by_key = _normalize_system_states(
		progress_snapshot.get(GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY, {})
	)


func get_progress_summary() -> Dictionary:
	var progress_summary: Dictionary = {
		"total": 0,
		"max_total": _global_state.get_total_level_count()
	}

	for track_key in _global_state.TRACK_KEYS:
		var completed_levels := 0
		var level_count: int = _global_state.get_track_level_count(track_key)
		for level_number in range(1, level_count + 1):
			if _global_state.is_level_completed(track_key, level_number):
				completed_levels += 1

		progress_summary[track_key] = completed_levels
		progress_summary["total"] = int(progress_summary.get("total", 0)) + completed_levels

	return progress_summary


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var resolved_track_key := track_key.strip_edges()
	var resolved_level_number := _resolve_track_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return {}

	var track_level_states := _read_partial_level_states_for_track(resolved_track_key)
	return _level_state_codec.normalize_level_state(
		track_level_states.get(str(resolved_level_number), {})
	)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var resolved_track_key := track_key.strip_edges()
	var resolved_level_number := _resolve_track_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return

	var track_level_states := _read_partial_level_states_for_track(resolved_track_key)
	var level_state_key := str(resolved_level_number)

	if _global_state.is_level_completed(resolved_track_key, resolved_level_number):
		track_level_states.erase(level_state_key)
		_global_state.partial_level_state_by_track[resolved_track_key] = track_level_states
		return

	var level_state_to_store: Dictionary = _level_state_codec.normalize_level_state(state)
	if level_state_to_store.is_empty():
		track_level_states.erase(level_state_key)
	else:
		track_level_states[level_state_key] = level_state_to_store

	_global_state.partial_level_state_by_track[resolved_track_key] = track_level_states


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var resolved_track_key := track_key.strip_edges()
	var resolved_level_number := _resolve_track_level_number(resolved_track_key, level_number)
	if resolved_level_number <= 0:
		return

	var track_level_states := _read_partial_level_states_for_track(resolved_track_key)
	track_level_states.erase(str(resolved_level_number))
	_global_state.partial_level_state_by_track[resolved_track_key] = track_level_states


func get_progress_system_state(system_key: String) -> Dictionary:
	var system_key_to_use := system_key.strip_edges()
	if system_key_to_use.is_empty():
		return {}
	if not _global_state.progress_system_state_by_key.has(system_key_to_use):
		return {}
	return _global_state.progress_system_state_by_key[system_key_to_use].duplicate(true)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	var system_key_to_use := system_key.strip_edges()
	if system_key_to_use.is_empty():
		return
	if system_state.is_empty():
		_global_state.progress_system_state_by_key.erase(system_key_to_use)
		return
	_global_state.progress_system_state_by_key[system_key_to_use] = system_state.duplicate(true)


func clear_progress_system_state(system_key: String) -> void:
	var system_key_to_use := system_key.strip_edges()
	if system_key_to_use.is_empty():
		return
	_global_state.progress_system_state_by_key.erase(system_key_to_use)


func _normalize_system_states(raw_system_states: Variant) -> Dictionary:
	if not raw_system_states is Dictionary:
		return {}

	var normalized_system_states: Dictionary = {}
	for raw_system_key in raw_system_states.keys():
		var system_key_to_use: String = str(raw_system_key).strip_edges()
		if system_key_to_use.is_empty():
			continue

		var stored_system_state: Variant = raw_system_states.get(raw_system_key, {})
		if not stored_system_state is Dictionary:
			continue

		normalized_system_states[system_key_to_use] = (
			stored_system_state as Dictionary
		).duplicate(true)

	return normalized_system_states


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


func _resolve_track_level_number(track_key: String, level_number: int) -> int:
	if track_key.is_empty() or not GameTrackCatalog.has_track(track_key):
		return 0

	var max_level_number: int = _global_state.get_track_level_count(track_key)
	if max_level_number <= 0:
		return 0

	return clampi(level_number, 1, max_level_number)


func _read_partial_level_states_for_track(track_key: String) -> Dictionary:
	var raw_track_partial_states: Variant = _global_state.partial_level_state_by_track.get(
		track_key,
		{}
	)
	return raw_track_partial_states if raw_track_partial_states is Dictionary else {}
