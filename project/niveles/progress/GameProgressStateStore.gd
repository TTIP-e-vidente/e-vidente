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
	var empty_partial_state_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		empty_partial_state_by_track[track_key] = {}
	return empty_partial_state_by_track


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
		progress_snapshot[track_key] = _build_track_completion_flags(track_key)

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
		_restore_track_completion_flags(track_key, progress_snapshot.get(track_key, []))

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
	var track_key_to_use := track_key.strip_edges()
	var level_number_to_use := _resolve_track_level_number(track_key_to_use, level_number)
	if level_number_to_use <= 0:
		return {}

	var track_partial_states := _get_partial_track_state_map(track_key_to_use)
	return _level_state_codec.normalize_level_state(
		track_partial_states.get(str(level_number_to_use), {})
	)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var track_key_to_use := track_key.strip_edges()
	var level_number_to_use := _resolve_track_level_number(track_key_to_use, level_number)
	if level_number_to_use <= 0:
		return

	var track_partial_states := _get_partial_track_state_map(track_key_to_use)
	var level_state_key := str(level_number_to_use)

	if _global_state.is_level_completed(track_key_to_use, level_number_to_use):
		track_partial_states.erase(level_state_key)
		_global_state.partial_level_state_by_track[track_key_to_use] = track_partial_states
		return

	var level_state_to_store: Dictionary = _level_state_codec.normalize_level_state(state)
	if level_state_to_store.is_empty():
		track_partial_states.erase(level_state_key)
	else:
		track_partial_states[level_state_key] = level_state_to_store

	_global_state.partial_level_state_by_track[track_key_to_use] = track_partial_states


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var track_key_to_use := track_key.strip_edges()
	var level_number_to_use := _resolve_track_level_number(track_key_to_use, level_number)
	if level_number_to_use <= 0:
		return

	var track_partial_states := _get_partial_track_state_map(track_key_to_use)
	track_partial_states.erase(str(level_number_to_use))
	_global_state.partial_level_state_by_track[track_key_to_use] = track_partial_states


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

	var normalized_state_by_key: Dictionary = {}
	for raw_system_key in raw_system_states.keys():
		var system_key_to_use: String = str(raw_system_key).strip_edges()
		if system_key_to_use.is_empty():
			continue

		var stored_system_state: Variant = raw_system_states.get(raw_system_key, {})
		if not stored_system_state is Dictionary:
			continue

		normalized_state_by_key[system_key_to_use] = (
			stored_system_state as Dictionary
		).duplicate(true)

	return normalized_state_by_key


func _build_track_completion_flags(track_key: String) -> Array:
	var completion_flags: Array = []
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		completion_flags.append(_global_state.is_level_completed(track_key, level_number))
	return completion_flags


func _restore_track_completion_flags(track_key: String, stored_flags: Variant) -> void:
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


func _get_partial_track_state_map(track_key: String) -> Dictionary:
	var raw_track_state_map: Variant = _global_state.partial_level_state_by_track.get(
		track_key,
		{}
	)
	return raw_track_state_map if raw_track_state_map is Dictionary else {}
