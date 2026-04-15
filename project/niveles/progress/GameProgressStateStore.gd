extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")
const GamePartialLevelStateCodecScript := preload(
	"res://niveles/progress/GamePartialLevelStateCodec.gd"
)

var _global_state
var _partial_level_state_codec


func _init(global_state):
	_global_state = global_state
	_partial_level_state_codec = GamePartialLevelStateCodecScript.new(global_state)


func build_empty_partial_level_state_map() -> Dictionary:
	var partial_states_by_track: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		partial_states_by_track[track_key] = {}
	return partial_states_by_track


func reset_progress() -> void:
	_global_state.campaign_progress_by_track = _global_state.build_default_campaign_progress_state()
	_global_state.partial_level_state_by_track = build_empty_partial_level_state_map()
	_global_state.progress_system_state_by_key = {}
	_global_state.set_current_level_number(1)


func export_progress() -> Dictionary:
	var snapshot: Dictionary = {"current_level": _global_state.get_current_level_number()}

	for track_key in _global_state.TRACK_KEYS:
		snapshot[track_key] = _build_track_completion_flags(track_key)

	snapshot[GameProgressKeys.PARTIAL_LEVEL_STATES_KEY] = (
		_partial_level_state_codec.export_track_states(
			_global_state.partial_level_state_by_track
		)
	)
	snapshot[GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY] = _normalize_system_states(
		_global_state.progress_system_state_by_key
	)
	return snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return

	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))

	for track_key in _global_state.TRACK_KEYS:
		_restore_track_completion_flags(track_key, progress_snapshot.get(track_key, []))

	_global_state.partial_level_state_by_track = _partial_level_state_codec.normalize_track_states(
		progress_snapshot.get(GameProgressKeys.PARTIAL_LEVEL_STATES_KEY, {})
	)
	_partial_level_state_codec.remove_completed_states(
		_global_state.partial_level_state_by_track
	)
	_global_state.progress_system_state_by_key = _normalize_system_states(
		progress_snapshot.get(GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY, {})
	)


func get_progress_summary() -> Dictionary:
	var summary: Dictionary = {
		"total": 0,
		"max_total": _global_state.get_total_level_count()
	}

	for track_key in _global_state.TRACK_KEYS:
		var completed_level_count: int = 0
		var level_count: int = _global_state.get_track_level_count(track_key)
		for level_number in range(1, level_count + 1):
			if _global_state.is_level_completed(track_key, level_number):
				completed_level_count += 1

		summary[track_key] = completed_level_count
		summary["total"] = int(summary.get("total", 0)) + completed_level_count

	return summary


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var clean_track_key: String = track_key.strip_edges()
	var resolved_level_number: int = _resolve_level_number(clean_track_key, level_number)
	if resolved_level_number <= 0:
		return {}

	var track_levels: Dictionary = _get_partial_track_levels(clean_track_key)
	return _partial_level_state_codec.normalize_level_state(
		track_levels.get(str(resolved_level_number), {})
	)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var clean_track_key: String = track_key.strip_edges()
	var resolved_level_number: int = _resolve_level_number(clean_track_key, level_number)
	if resolved_level_number <= 0:
		return

	var track_levels: Dictionary = _get_partial_track_levels(clean_track_key)
	var level_key: String = str(resolved_level_number)

	if _global_state.is_level_completed(clean_track_key, resolved_level_number):
		track_levels.erase(level_key)
		_global_state.partial_level_state_by_track[clean_track_key] = track_levels
		return

	var normalized_level_state: Dictionary = _partial_level_state_codec.normalize_level_state(state)
	if normalized_level_state.is_empty():
		track_levels.erase(level_key)
	else:
		track_levels[level_key] = normalized_level_state

	_global_state.partial_level_state_by_track[clean_track_key] = track_levels


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var clean_track_key: String = track_key.strip_edges()
	var resolved_level_number: int = _resolve_level_number(clean_track_key, level_number)
	if resolved_level_number <= 0:
		return

	var track_levels: Dictionary = _get_partial_track_levels(clean_track_key)
	track_levels.erase(str(resolved_level_number))
	_global_state.partial_level_state_by_track[clean_track_key] = track_levels


func get_progress_system_state(system_key: String) -> Dictionary:
	var clean_system_key: String = system_key.strip_edges()
	if clean_system_key.is_empty():
		return {}
	if not _global_state.progress_system_state_by_key.has(clean_system_key):
		return {}
	return _global_state.progress_system_state_by_key[clean_system_key].duplicate(true)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	var clean_system_key: String = system_key.strip_edges()
	if clean_system_key.is_empty():
		return
	if system_state.is_empty():
		_global_state.progress_system_state_by_key.erase(clean_system_key)
		return
	_global_state.progress_system_state_by_key[clean_system_key] = system_state.duplicate(true)


func clear_progress_system_state(system_key: String) -> void:
	var clean_system_key: String = system_key.strip_edges()
	if clean_system_key.is_empty():
		return
	_global_state.progress_system_state_by_key.erase(clean_system_key)


func _normalize_system_states(raw_system_states: Variant) -> Dictionary:
	if not raw_system_states is Dictionary:
		return {}

	var normalized_states: Dictionary = {}
	for raw_key in raw_system_states.keys():
		var clean_key: String = str(raw_key).strip_edges()
		if clean_key.is_empty():
			continue

		var raw_state: Variant = raw_system_states.get(raw_key, {})
		if not raw_state is Dictionary:
			continue

		normalized_states[clean_key] = (raw_state as Dictionary).duplicate(true)

	return normalized_states


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
	var completion_flags: Array = stored_flags

	for level_index in range(min(completion_flags.size(), level_count)):
		var level_number: int = level_index + 1
		var raw_level_progress: Variant = track_progress.get(level_number, {})
		if not raw_level_progress is Dictionary:
			continue

		var level_progress: Dictionary = raw_level_progress
		level_progress[_global_state.BOOK_LEVEL_COMPLETED_KEY] = bool(
			completion_flags[level_index]
		)
		track_progress[level_number] = level_progress


func _resolve_level_number(track_key: String, level_number: int) -> int:
	if track_key.is_empty() or not GameTrackCatalog.has_track(track_key):
		return 0

	var max_level_number: int = _global_state.get_track_level_count(track_key)
	if max_level_number <= 0:
		return 0

	return clampi(level_number, 1, max_level_number)


func _get_partial_track_levels(track_key: String) -> Dictionary:
	var raw_track_levels: Variant = _global_state.partial_level_state_by_track.get(
		track_key,
		{}
	)
	return raw_track_levels if raw_track_levels is Dictionary else {}
