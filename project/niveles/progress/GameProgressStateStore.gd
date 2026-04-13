extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GamePartialLevelStateCodecScript := preload(
	"res://niveles/progress/GamePartialLevelStateCodec.gd"
)

var _global_state
var _level_state_reader


func _init(global_state):
	_global_state = global_state
	_level_state_reader = GamePartialLevelStateCodecScript.new(global_state)


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
		progress_snapshot[track_key] = _build_track_completion_flags(track_key)
	progress_snapshot[_global_state.PARTIAL_LEVEL_STATES_KEY] = (
		_level_state_reader.export_track_states(
			_global_state.partial_level_state_by_track
		)
	)
	progress_snapshot[_global_state.PROGRESS_SYSTEM_STATES_KEY] = (
		_read_system_states(_global_state.progress_system_state_by_key)
	)
	return progress_snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return

	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))
	for track_key in _global_state.TRACK_KEYS:
		_load_track_completion_flags(track_key, progress_snapshot.get(track_key, []))

	_global_state.partial_level_state_by_track = (
		_level_state_reader.read_track_states(
			progress_snapshot.get(_global_state.PARTIAL_LEVEL_STATES_KEY, {})
		)
	)
	_level_state_reader.remove_completed_states(
		_global_state.partial_level_state_by_track
	)
	_global_state.progress_system_state_by_key = _read_system_states(
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
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty() or not GameTrackCatalog.has_track(clean_track_key):
		return {}

	var max_level_number: int = _global_state.get_track_level_count(clean_track_key)
	if max_level_number <= 0:
		return {}
	var clean_level_number := clampi(level_number, 1, max_level_number)

	var raw_levels = _global_state.partial_level_state_by_track.get(clean_track_key, {})
	var levels: Dictionary = raw_levels if raw_levels is Dictionary else {}
	return _level_state_reader.read_level_state(
		levels.get(str(clean_level_number), {})
	)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty() or not GameTrackCatalog.has_track(clean_track_key):
		return

	var max_level_number: int = _global_state.get_track_level_count(clean_track_key)
	if max_level_number <= 0:
		return
	var clean_level_number := clampi(level_number, 1, max_level_number)

	var raw_levels = _global_state.partial_level_state_by_track.get(clean_track_key, {})
	var levels: Dictionary = raw_levels if raw_levels is Dictionary else {}
	if _global_state.is_level_completed(clean_track_key, clean_level_number):
		levels.erase(str(clean_level_number))
		_global_state.partial_level_state_by_track[clean_track_key] = levels
		return

	var level_state = _level_state_reader.read_level_state(state)
	if level_state.is_empty():
		levels.erase(str(clean_level_number))
	else:
		levels[str(clean_level_number)] = level_state
	_global_state.partial_level_state_by_track[clean_track_key] = levels


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty() or not GameTrackCatalog.has_track(clean_track_key):
		return

	var max_level_number: int = _global_state.get_track_level_count(clean_track_key)
	if max_level_number <= 0:
		return
	var clean_level_number := clampi(level_number, 1, max_level_number)

	var raw_levels = _global_state.partial_level_state_by_track.get(clean_track_key, {})
	var levels: Dictionary = raw_levels if raw_levels is Dictionary else {}
	levels.erase(str(clean_level_number))
	_global_state.partial_level_state_by_track[clean_track_key] = levels


func get_progress_system_state(system_key: String) -> Dictionary:
	var clean_system_key := system_key.strip_edges()
	if clean_system_key.is_empty():
		return {}

	if not _global_state.progress_system_state_by_key.has(clean_system_key):
		_global_state.progress_system_state_by_key[clean_system_key] = {}

	var system_state = _global_state.progress_system_state_by_key.get(clean_system_key, {})
	if system_state is Dictionary:
		return system_state

	_global_state.progress_system_state_by_key[clean_system_key] = {}
	return _global_state.progress_system_state_by_key[clean_system_key]


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	var clean_system_key := system_key.strip_edges()
	if clean_system_key.is_empty():
		return
	if system_state.is_empty():
		_global_state.progress_system_state_by_key.erase(clean_system_key)
		return
	_global_state.progress_system_state_by_key[clean_system_key] = system_state.duplicate(true)


func clear_progress_system_state(system_key: String) -> void:
	var clean_system_key := system_key.strip_edges()
	if clean_system_key.is_empty():
		return
	_global_state.progress_system_state_by_key.erase(clean_system_key)


func _read_system_states(raw_progress_system_states: Variant) -> Dictionary:
	if not raw_progress_system_states is Dictionary:
		return build_empty_progress_system_state_map()

	var copied_states_by_key: Dictionary = {}
	for raw_system_key in raw_progress_system_states.keys():
		var clean_system_key := str(raw_system_key).strip_edges()
		if clean_system_key.is_empty():
			continue

		var raw_system_state: Variant = raw_progress_system_states.get(raw_system_key, {})
		if not raw_system_state is Dictionary:
			continue
		copied_states_by_key[clean_system_key] = (
			(raw_system_state as Dictionary).duplicate(true)
		)
	return copied_states_by_key


func _build_track_completion_flags(track_key: String) -> Array:
	var completion_flags: Array = []
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		completion_flags.append(_global_state.is_level_completed(track_key, level_number))
	return completion_flags


func _load_track_completion_flags(track_key: String, stored_completion_flags: Variant) -> void:
	if not stored_completion_flags is Array:
		return

	var track_progress: Dictionary = _global_state.get_campaign_progress_for_track(track_key)
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_index in range(min(stored_completion_flags.size(), level_count)):
		var level_number: int = level_index + 1
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
