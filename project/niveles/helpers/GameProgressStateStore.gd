extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GamePartialLevelStateCodecScript := preload(
	"res://niveles/helpers/GamePartialLevelStateCodec.gd"
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


func build_empty_progress_system_state_map() -> Dictionary:
	return {}


func reset_progress() -> void:
	_global_state.campaign_progress_by_track = _global_state.build_default_campaign_progress_state()
	_global_state.partial_level_state_by_track = build_empty_partial_level_state_map()
	_global_state.progress_system_state_by_key = build_empty_progress_system_state_map()
	_global_state.set_current_level_number(1)


func export_progress() -> Dictionary:
	var progress_snapshot: Dictionary = {
		"current_level": _global_state.get_current_level_number()
	}
	for track_key in _global_state.TRACK_KEYS:
		progress_snapshot[track_key] = _export_track_completion_flags(track_key)
	progress_snapshot[_global_state.PARTIAL_LEVEL_STATES_KEY] = (
		_partial_level_state_codec.export_track_partial_level_states(
			_global_state.partial_level_state_by_track
		)
	)
	progress_snapshot[_global_state.PROGRESS_SYSTEM_STATES_KEY] = (
		_export_progress_system_states()
	)
	return progress_snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return

	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))
	for track_key in _global_state.TRACK_KEYS:
		_restore_track_completion_flags(track_key, progress_snapshot.get(track_key, []))

	_global_state.partial_level_state_by_track = (
		_partial_level_state_codec.normalize_track_partial_level_states(
			progress_snapshot.get(_global_state.PARTIAL_LEVEL_STATES_KEY, {})
		)
	)
	_partial_level_state_codec.remove_completed_level_states(
		_global_state.partial_level_state_by_track
	)
	_global_state.progress_system_state_by_key = _restore_progress_system_states(
		progress_snapshot.get(_global_state.PROGRESS_SYSTEM_STATES_KEY, {})
	)


func get_progress_summary() -> Dictionary:
	var summary: Dictionary = {
		"total": 0,
		"max_total": _global_state.get_total_level_count()
	}
	for track_key in _global_state.TRACK_KEYS:
		var completed_level_count: int = _count_completed_levels(track_key)
		summary[track_key] = completed_level_count
		summary["total"] = int(summary.get("total", 0)) + completed_level_count
	return summary


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var clean_track_key: String = _get_valid_track_key(track_key)
	if clean_track_key.is_empty():
		return {}

	var clean_level_number: int = clampi(
		level_number,
		1,
		_global_state.get_track_level_count(clean_track_key)
	)
	var partial_states_for_track: Dictionary = _read_partial_states_for_track(clean_track_key)
	return _partial_level_state_codec.normalize_partial_level_state(
		partial_states_for_track.get(str(clean_level_number), {})
	)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var clean_track_key: String = _get_valid_track_key(track_key)
	if clean_track_key.is_empty():
		return

	var clean_level_number: int = clampi(
		level_number,
		1,
		_global_state.get_track_level_count(clean_track_key)
	)
	var partial_states_for_track: Dictionary = _read_partial_states_for_track(clean_track_key)
	if _global_state.is_level_completed(clean_track_key, clean_level_number):
		partial_states_for_track.erase(str(clean_level_number))
		_global_state.partial_level_state_by_track[clean_track_key] = partial_states_for_track
		return

	var normalized_state: Dictionary = _partial_level_state_codec.normalize_partial_level_state(
		state
	)
	if normalized_state.is_empty():
		partial_states_for_track.erase(str(clean_level_number))
	else:
		partial_states_for_track[str(clean_level_number)] = normalized_state
	_global_state.partial_level_state_by_track[clean_track_key] = partial_states_for_track


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var clean_track_key: String = _get_valid_track_key(track_key)
	if clean_track_key.is_empty():
		return

	var clean_level_number: int = clampi(
		level_number,
		1,
		_global_state.get_track_level_count(clean_track_key)
	)
	var partial_states_for_track: Dictionary = _read_partial_states_for_track(clean_track_key)
	partial_states_for_track.erase(str(clean_level_number))
	_global_state.partial_level_state_by_track[clean_track_key] = partial_states_for_track


func get_progress_system_state(system_key: String) -> Dictionary:
	var clean_system_key: String = _get_valid_system_key(system_key)
	if clean_system_key.is_empty():
		return {}

	if not _global_state.progress_system_state_by_key.has(clean_system_key):
		_global_state.progress_system_state_by_key[clean_system_key] = {}
	var raw_system_state: Variant = _global_state.progress_system_state_by_key.get(
		clean_system_key,
		{}
	)
	if raw_system_state is Dictionary:
		return raw_system_state
	return {}


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	var clean_system_key: String = _get_valid_system_key(system_key)
	if clean_system_key.is_empty():
		return
	if system_state.is_empty():
		_global_state.progress_system_state_by_key.erase(clean_system_key)
		return
	_global_state.progress_system_state_by_key[clean_system_key] = system_state.duplicate(true)


func clear_progress_system_state(system_key: String) -> void:
	var clean_system_key: String = _get_valid_system_key(system_key)
	if clean_system_key.is_empty():
		return
	_global_state.progress_system_state_by_key.erase(clean_system_key)


func _export_progress_system_states() -> Dictionary:
	var exported_states_by_key: Dictionary = {}
	for raw_system_key in _global_state.progress_system_state_by_key.keys():
		var clean_system_key: String = _get_valid_system_key(str(raw_system_key))
		if clean_system_key.is_empty():
			continue

		var raw_system_state: Variant = _global_state.progress_system_state_by_key.get(
			raw_system_key,
			{}
		)
		if not raw_system_state is Dictionary:
			continue
		exported_states_by_key[clean_system_key] = (
			(raw_system_state as Dictionary).duplicate(true)
		)
	return exported_states_by_key


func _restore_progress_system_states(raw_progress_system_states: Variant) -> Dictionary:
	if not raw_progress_system_states is Dictionary:
		return build_empty_progress_system_state_map()

	var restored_states_by_key: Dictionary = {}
	for raw_system_key in raw_progress_system_states.keys():
		var clean_system_key: String = _get_valid_system_key(str(raw_system_key))
		if clean_system_key.is_empty():
			continue

		var raw_system_state: Variant = raw_progress_system_states.get(raw_system_key, {})
		if not raw_system_state is Dictionary:
			continue
		restored_states_by_key[clean_system_key] = (
			(raw_system_state as Dictionary).duplicate(true)
		)
	return restored_states_by_key


func _export_track_completion_flags(track_key: String) -> Array:
	var completion_flags: Array = []
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		completion_flags.append(_global_state.is_level_completed(track_key, level_number))
	return completion_flags


func _restore_track_completion_flags(track_key: String, stored_completion_flags: Variant) -> void:
	if not stored_completion_flags is Array:
		return

	var track_progress: Dictionary = _global_state.get_campaign_progress_for_track(track_key)
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_index in range(min(stored_completion_flags.size(), level_count)):
		var level_number: int = level_index + 1
		if not track_progress.has(level_number):
			continue
		_set_level_completed_flag(
			track_progress,
			level_number,
			bool(stored_completion_flags[level_index])
		)


func _count_completed_levels(track_key: String) -> int:
	var completed_level_count: int = 0
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		if _global_state.is_level_completed(track_key, level_number):
			completed_level_count += 1
	return completed_level_count


func _set_level_completed_flag(
	track_progress: Dictionary,
	level_number: int,
	completed: bool
) -> void:
	var raw_level_progress: Variant = track_progress.get(level_number, {})
	if not raw_level_progress is Dictionary:
		return
	var level_progress: Dictionary = raw_level_progress
	level_progress[_global_state.BOOK_LEVEL_COMPLETED_KEY] = completed
	track_progress[level_number] = level_progress


func _read_partial_states_for_track(track_key: String) -> Dictionary:
	var raw_partial_states: Variant = _global_state.partial_level_state_by_track.get(
		track_key,
		{}
	)
	if raw_partial_states is Dictionary:
		return raw_partial_states
	return {}


func _get_valid_track_key(track_key: String) -> String:
	var clean_track_key: String = track_key.strip_edges()
	if GameTrackCatalog.has_track(clean_track_key):
		return clean_track_key
	return ""


func _get_valid_system_key(system_key: String) -> String:
	return system_key.strip_edges()
