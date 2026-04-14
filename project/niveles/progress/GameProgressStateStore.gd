extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
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


func build_empty_progress_system_state_map() -> Dictionary:
	return {}


func reset_progress() -> void:
	_reset_campaign_progress()
	_reset_partial_level_states()
	_reset_progress_system_states()
	_global_state.set_current_level_number(1)


func export_progress() -> Dictionary:
	var snapshot: Dictionary = {
		"current_level": _global_state.get_current_level_number()
	}
	_append_track_completion_flags(snapshot)
	snapshot[_global_state.PARTIAL_LEVEL_STATES_KEY] = (
		_partial_level_state_codec.export_track_states(_global_state.partial_level_state_by_track)
	)
	snapshot[_global_state.PROGRESS_SYSTEM_STATES_KEY] = (
		_normalize_system_states(_global_state.progress_system_state_by_key)
	)
	return snapshot


func import_progress(progress_snapshot: Dictionary) -> void:
	reset_progress()
	if progress_snapshot.is_empty():
		return

	_restore_current_level(progress_snapshot)
	_restore_track_completion_flags(progress_snapshot)
	_restore_partial_level_states(progress_snapshot)
	_restore_progress_system_states(progress_snapshot)


func get_progress_summary() -> Dictionary:
	var summary: Dictionary = {
		"total": 0,
		"max_total": _global_state.get_total_level_count()
	}
	for track_key in _global_state.TRACK_KEYS:
		var completed := _count_completed_levels(track_key)
		summary[track_key] = completed
		summary["total"] = int(summary.get("total", 0)) + completed
	return summary


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var resolved_track_key: String = _resolve_existing_track_key(track_key)
	if resolved_track_key.is_empty():
		return {}

	var resolved_level_number: int = _resolve_track_level_number(
		resolved_track_key,
		level_number
	)
	if resolved_level_number <= 0:
		return {}
	return _read_partial_level_state(resolved_track_key, resolved_level_number)


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var resolved_track_key: String = _resolve_existing_track_key(track_key)
	if resolved_track_key.is_empty():
		return

	var resolved_level_number: int = _resolve_track_level_number(
		resolved_track_key,
		level_number
	)
	if resolved_level_number <= 0:
		return

	if _should_drop_partial_level_state(resolved_track_key, resolved_level_number):
		_erase_partial_level_state(resolved_track_key, resolved_level_number)
		return

	var partial_level_state: Dictionary = _partial_level_state_codec.normalize_level_state(state)
	_store_partial_level_state(
		resolved_track_key,
		resolved_level_number,
		partial_level_state
	)


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var resolved_track_key: String = _resolve_existing_track_key(track_key)
	if resolved_track_key.is_empty():
		return

	var resolved_level_number: int = _resolve_track_level_number(
		resolved_track_key,
		level_number
	)
	if resolved_level_number <= 0:
		return
	_erase_partial_level_state(resolved_track_key, resolved_level_number)


func get_progress_system_state(system_key: String) -> Dictionary:
	var clean_system_key := system_key.strip_edges()
	if clean_system_key.is_empty():
		return {}

	# Auto-crear un estado vacío si este sistema nunca guardó nada
	if not _global_state.progress_system_state_by_key.has(clean_system_key):
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


func _reset_campaign_progress() -> void:
	_global_state.campaign_progress_by_track = _global_state.build_default_campaign_progress_state()


func _reset_partial_level_states() -> void:
	_global_state.partial_level_state_by_track = build_empty_partial_level_state_map()


func _reset_progress_system_states() -> void:
	_global_state.progress_system_state_by_key = build_empty_progress_system_state_map()


func _append_track_completion_flags(snapshot: Dictionary) -> void:
	for track_key in _global_state.TRACK_KEYS:
		snapshot[track_key] = _build_track_completion_flags(track_key)


func _restore_current_level(progress_snapshot: Dictionary) -> void:
	_global_state.set_current_level_number(int(progress_snapshot.get("current_level", 1)))


func _restore_track_completion_flags(progress_snapshot: Dictionary) -> void:
	for track_key in _global_state.TRACK_KEYS:
		_load_track_completion_flags(track_key, progress_snapshot.get(track_key, []))


func _restore_partial_level_states(progress_snapshot: Dictionary) -> void:
	_global_state.partial_level_state_by_track = (
		_partial_level_state_codec.normalize_track_states(
			progress_snapshot.get(_global_state.PARTIAL_LEVEL_STATES_KEY, {})
		)
	)
	_partial_level_state_codec.remove_completed_states(
		_global_state.partial_level_state_by_track
	)


func _restore_progress_system_states(progress_snapshot: Dictionary) -> void:
	_global_state.progress_system_state_by_key = _normalize_system_states(
		progress_snapshot.get(_global_state.PROGRESS_SYSTEM_STATES_KEY, {})
	)


func _resolve_existing_track_key(track_key: String) -> String:
	var normalized_track_key := track_key.strip_edges()
	if normalized_track_key.is_empty() or not GameTrackCatalog.has_track(normalized_track_key):
		return ""
	return normalized_track_key


func _resolve_track_level_number(track_key: String, level_number: int) -> int:
	var max_level_number: int = _global_state.get_track_level_count(track_key)
	if max_level_number <= 0:
		return 0
	return clampi(level_number, 1, max_level_number)


func _read_track_partial_states(track_key: String) -> Dictionary:
	var raw_track_levels: Variant = _global_state.partial_level_state_by_track.get(
		track_key,
		{}
	)
	return raw_track_levels if raw_track_levels is Dictionary else {}


func _write_track_partial_states(track_key: String, track_levels: Dictionary) -> void:
	_global_state.partial_level_state_by_track[track_key] = track_levels


func _read_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var track_levels: Dictionary = _read_track_partial_states(track_key)
	var level_key := str(level_number)
	return _partial_level_state_codec.normalize_level_state(
		track_levels.get(level_key, {})
	)


func _store_partial_level_state(
	track_key: String,
	level_number: int,
	partial_level_state: Dictionary
) -> void:
	if partial_level_state.is_empty():
		_erase_partial_level_state(track_key, level_number)
		return

	var track_levels: Dictionary = _read_track_partial_states(track_key)
	var level_key := str(level_number)
	track_levels[level_key] = partial_level_state
	_write_track_partial_states(track_key, track_levels)


func _erase_partial_level_state(track_key: String, level_number: int) -> void:
	var track_levels: Dictionary = _read_track_partial_states(track_key)
	var level_key := str(level_number)
	track_levels.erase(level_key)
	_write_track_partial_states(track_key, track_levels)


func _should_drop_partial_level_state(track_key: String, level_number: int) -> bool:
	return _global_state.is_level_completed(track_key, level_number)


func _normalize_system_states(raw_system_states: Variant) -> Dictionary:
	if not raw_system_states is Dictionary:
		return build_empty_progress_system_state_map()

	var result: Dictionary = {}
	for raw_key in raw_system_states.keys():
		var clean_key := str(raw_key).strip_edges()
		if clean_key.is_empty():
			continue

		var raw_state: Variant = raw_system_states.get(raw_key, {})
		if not raw_state is Dictionary:
			continue
		result[clean_key] = (raw_state as Dictionary).duplicate(true)
	return result


func _build_track_completion_flags(track_key: String) -> Array:
	var flags: Array = []
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		flags.append(_global_state.is_level_completed(track_key, level_number))
	return flags


func _load_track_completion_flags(track_key: String, stored_flags: Variant) -> void:
	if not stored_flags is Array:
		return

	var track_progress: Dictionary = _global_state.get_campaign_progress_for_track(track_key)
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_index in range(min(stored_flags.size(), level_count)):
		var level_number := level_index + 1
		_set_level_completed_flag(track_progress, level_number, bool(stored_flags[level_index]))


func _count_completed_levels(track_key: String) -> int:
	var count := 0
	var level_count: int = _global_state.get_track_level_count(track_key)
	for level_number in range(1, level_count + 1):
		if _global_state.is_level_completed(track_key, level_number):
			count += 1
	return count


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
