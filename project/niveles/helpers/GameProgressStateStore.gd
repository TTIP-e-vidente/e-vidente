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
	var empty_track_state_map: Dictionary = {}
	for track_key in _global_state.TRACK_KEYS:
		empty_track_state_map[track_key] = {}
	return empty_track_state_map


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
		progress_snapshot[track_key] = _export_track_completion_flags(
			_global_state.get_campaign_progress_for_track(track_key),
			track_key
		)
	progress_snapshot[_global_state.PARTIAL_LEVEL_STATES_KEY] = (
		_partial_level_state_codec.export_track_partial_level_states(
			_global_state.partial_level_state_by_track
		)
	)
	progress_snapshot[_global_state.PROGRESS_SYSTEM_STATES_KEY] = (
		_export_progress_system_state_by_key()
	)
	return progress_snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return
	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))
	for track_key in _global_state.TRACK_KEYS:
		_restore_track_completion_flags(
			_global_state.get_campaign_progress_for_track(track_key),
			track_key,
			progress_snapshot.get(track_key, [])
		)
	_global_state.partial_level_state_by_track = (
		_partial_level_state_codec.normalize_track_partial_level_states(
			progress_snapshot.get(_global_state.PARTIAL_LEVEL_STATES_KEY, {})
		)
	)
	_partial_level_state_codec.remove_completed_level_states(
		_global_state.partial_level_state_by_track
	)
	_global_state.progress_system_state_by_key = _normalize_progress_system_state_by_key(
		progress_snapshot.get(_global_state.PROGRESS_SYSTEM_STATES_KEY, {})
	)


func get_progress_summary() -> Dictionary:
	var progress_summary: Dictionary = {
		"total": 0,
		"max_total": _global_state.get_total_level_count()
	}
	for track_key in _global_state.TRACK_KEYS:
		var completed_level_count := _count_completed_levels_for_track(
			_global_state.get_campaign_progress_for_track(track_key),
			track_key
		)
		progress_summary[track_key] = completed_level_count
		progress_summary["total"] = int(progress_summary.get("total", 0)) + completed_level_count
	return progress_summary


# Estado parcial por nivel: lo que permite retomar una corrida sin completar.
func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var clean_track_key := _resolve_track_key(track_key)
	if clean_track_key.is_empty():
		return {}
	return _read_partial_level_state(clean_track_key, level_number)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var clean_track_key := _resolve_track_key(track_key)
	if clean_track_key.is_empty():
		return
	var resolved_level_number := _resolve_level_number(clean_track_key, level_number)
	if _global_state.is_level_completed(clean_track_key, resolved_level_number):
		_write_partial_level_state(clean_track_key, resolved_level_number, {})
		return
	_write_partial_level_state(
		clean_track_key,
		resolved_level_number,
		_normalize_partial_level_state(state)
	)


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var clean_track_key := _resolve_track_key(track_key)
	if clean_track_key.is_empty():
		return
	_write_partial_level_state(
		clean_track_key,
		_resolve_level_number(clean_track_key, level_number),
		{}
	)


# Estado auxiliar para sistemas que necesitan persistencia propia.
func get_progress_system_state(system_key: String) -> Dictionary:
	var clean_system_key := _resolve_progress_system_key(system_key)
	if clean_system_key.is_empty():
		return {}
	if not _global_state.progress_system_state_by_key.has(clean_system_key):
		_global_state.progress_system_state_by_key[clean_system_key] = {}
	var stored_system_state: Variant = _global_state.progress_system_state_by_key.get(
		clean_system_key,
		{}
	)
	return stored_system_state if stored_system_state is Dictionary else {}


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	var clean_system_key := _resolve_progress_system_key(system_key)
	if clean_system_key.is_empty():
		return
	if system_state.is_empty():
		clear_progress_system_state(clean_system_key)
		return
	_global_state.progress_system_state_by_key[clean_system_key] = system_state.duplicate(true)


func clear_progress_system_state(system_key: String) -> void:
	var clean_system_key := _resolve_progress_system_key(system_key)
	if clean_system_key.is_empty():
		return
	_global_state.progress_system_state_by_key.erase(clean_system_key)
func _export_progress_system_state_by_key() -> Dictionary:
	var exported_progress_system_state_by_key: Dictionary = {}
	for raw_system_key in _global_state.progress_system_state_by_key.keys():
		var clean_system_key := _resolve_progress_system_key(str(raw_system_key))
		if clean_system_key.is_empty():
			continue
		var system_state: Variant = _global_state.progress_system_state_by_key.get(
			raw_system_key,
			{}
		)
		if not system_state is Dictionary:
			continue
		exported_progress_system_state_by_key[clean_system_key] = (
			(system_state as Dictionary).duplicate(true)
		)
	return exported_progress_system_state_by_key


func _normalize_progress_system_state_by_key(
	raw_progress_system_state_by_key: Variant
) -> Dictionary:
	if not raw_progress_system_state_by_key is Dictionary:
		return build_empty_progress_system_state_map()
	var normalized_progress_system_state_by_key: Dictionary = {}
	for raw_system_key in raw_progress_system_state_by_key.keys():
		var clean_system_key := _resolve_progress_system_key(str(raw_system_key))
		if clean_system_key.is_empty():
			continue
		var system_state: Variant = raw_progress_system_state_by_key.get(raw_system_key, {})
		if not system_state is Dictionary:
			continue
		normalized_progress_system_state_by_key[clean_system_key] = (
			(system_state as Dictionary).duplicate(true)
		)
	return normalized_progress_system_state_by_key


func _read_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var level_key := _resolve_level_key(track_key, level_number)
	var track_partial_state: Dictionary = _read_partial_level_state_for_track(track_key)
	return _normalize_partial_level_state(track_partial_state.get(level_key, {}))


func _write_partial_level_state(
	track_key: String,
	level_number: int,
	state: Dictionary
) -> void:
	var level_key := _resolve_level_key(track_key, level_number)
	var track_partial_state: Dictionary = _read_partial_level_state_for_track(track_key)
	if state.is_empty():
		track_partial_state.erase(level_key)
	else:
		track_partial_state[level_key] = state
	_global_state.partial_level_state_by_track[track_key] = track_partial_state


func _normalize_partial_level_state(state: Variant) -> Dictionary:
	return _partial_level_state_codec.normalize_partial_level_state(state)


func _export_track_completion_flags(track_progress: Dictionary, track_key: String) -> Array:
	var exported_completion_flags: Array = []
	for level_number in range(1, _global_state.get_track_level_count(track_key) + 1):
		exported_completion_flags.append(
			_is_track_level_completed(track_progress, level_number)
		)
	return exported_completion_flags


func _restore_track_completion_flags(
	track_progress: Dictionary,
	track_key: String,
	stored_completion_flags: Variant
) -> void:
	if not stored_completion_flags is Array:
		return
	for level_index in range(
		min(stored_completion_flags.size(), _global_state.get_track_level_count(track_key))
	):
		var level_number := level_index + 1
		if not track_progress.has(level_number):
			continue
		_write_track_level_completion(
			track_progress,
			level_number,
			bool(stored_completion_flags[level_index])
		)


func _count_completed_levels_for_track(track_progress: Dictionary, track_key: String) -> int:
	var completed_level_count := 0
	for level_number in range(1, _global_state.get_track_level_count(track_key) + 1):
		if _is_track_level_completed(track_progress, level_number):
			completed_level_count += 1
	return completed_level_count


func _is_track_level_completed(track_progress: Dictionary, level_number: int) -> bool:
	var raw_level_progress: Variant = track_progress.get(level_number, {})
	if not raw_level_progress is Dictionary:
		return false
	return bool(
		(raw_level_progress as Dictionary).get(_global_state.BOOK_LEVEL_COMPLETED_KEY, false)
	)


func _write_track_level_completion(
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


func _resolve_track_key(track_key: String) -> String:
	var clean_track_key := track_key.strip_edges()
	if GameTrackCatalog.has_track(clean_track_key):
		return clean_track_key
	return ""


func _resolve_progress_system_key(system_key: String) -> String:
	return system_key.strip_edges()


func _resolve_level_number(track_key: String, level_number: int) -> int:
	return clampi(level_number, 1, _global_state.get_track_level_count(track_key))


func _resolve_level_key(track_key: String, level_number: int) -> String:
	return str(_resolve_level_number(track_key, level_number))


func _read_partial_level_state_for_track(track_key: String) -> Dictionary:
	var raw_track_partial_state: Variant = _global_state.partial_level_state_by_track.get(
		track_key,
		{}
	)
	return raw_track_partial_state if raw_track_partial_state is Dictionary else {}
