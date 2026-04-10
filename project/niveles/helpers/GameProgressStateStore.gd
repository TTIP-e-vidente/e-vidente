extends RefCounted

const GamePartialLevelStateCodecScript := preload("res://niveles/helpers/GamePartialLevelStateCodec.gd")

var _manager
var _partial_state_codec

func _init(manager):
	_manager = manager
	_partial_state_codec = GamePartialLevelStateCodecScript.new(manager)

func build_default_partial_level_states() -> Dictionary:
	var default_states: Dictionary = {}
	for track_key in _manager.TRACK_KEYS:
		default_states[track_key] = {}
	return default_states

func reset_progress() -> void:
	for track_key in _manager.TRACK_KEYS:
		_reset_book_progress(_manager._book_for_track(track_key), track_key)
	_manager.current_level = 1
	_manager.partial_level_states = build_default_partial_level_states()

func export_progress() -> Dictionary:
	var progress: Dictionary = {"current_level": _manager.current_level, _manager.PARTIAL_LEVEL_STATES_KEY: _partial_state_codec.export_partial_level_states(_manager.partial_level_states)}
	for track_key in _manager.TRACK_KEYS:
		progress[track_key] = _export_book_progress(_manager._book_for_track(track_key), track_key)
	return progress

func import_progress(progress: Dictionary) -> void:
	reset_progress()
	if progress.is_empty():
		return
	_manager.current_level = clampi(int(progress.get("current_level", 1)), 1, _manager.get_max_track_level_count())
	for track_key in _manager.TRACK_KEYS:
		_import_book_progress(_manager._book_for_track(track_key), track_key, progress.get(track_key, []))
	_manager.partial_level_states = _partial_state_codec.normalize_partial_level_states(progress.get(_manager.PARTIAL_LEVEL_STATES_KEY, {}))
	_partial_state_codec.prune_partial_level_states(_manager.partial_level_states)

func get_progress_summary() -> Dictionary:
	var summary: Dictionary = {"total": 0, "max_total": _manager.get_total_level_count()}
	for track_key in _manager.TRACK_KEYS:
		var completed_levels: int = _count_completed_levels(_manager._book_for_track(track_key), track_key)
		summary[track_key] = completed_levels
		summary["total"] = int(summary.get("total", 0)) + completed_levels
	return summary

func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var clean_track_key := track_key.strip_edges()
	if not _manager.has_track(clean_track_key):
		return {}
	var track_states: Variant = _manager.partial_level_states.get(clean_track_key, {})
	if not track_states is Dictionary:
		return {}
	var clean_level_number := clampi(level_number, 1, _manager.get_track_level_count(clean_track_key))
	return _partial_state_codec.normalize_partial_level_state(track_states.get(str(clean_level_number), {}))

func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var clean_track_key := track_key.strip_edges()
	if not _manager.has_track(clean_track_key):
		return
	var clean_level_number := clampi(level_number, 1, _manager.get_track_level_count(clean_track_key))
	var raw_track_states: Variant = _manager.partial_level_states.get(clean_track_key, {})
	var track_states: Dictionary = {}
	if raw_track_states is Dictionary:
		track_states = raw_track_states
	if _manager._is_level_completed(clean_track_key, clean_level_number):
		track_states.erase(str(clean_level_number))
		_manager.partial_level_states[clean_track_key] = track_states
		return
	var normalized_state: Dictionary = _partial_state_codec.normalize_partial_level_state(state)
	if normalized_state.is_empty():
		track_states.erase(str(clean_level_number))
	else:
		track_states[str(clean_level_number)] = normalized_state
	_manager.partial_level_states[clean_track_key] = track_states

func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var clean_track_key := track_key.strip_edges()
	if not _manager.has_track(clean_track_key):
		return
	var clean_level_number := clampi(level_number, 1, _manager.get_track_level_count(clean_track_key))
	var raw_track_states: Variant = _manager.partial_level_states.get(clean_track_key, {})
	var track_states: Dictionary = {}
	if raw_track_states is Dictionary:
		track_states = raw_track_states
	track_states.erase(str(clean_level_number))
	_manager.partial_level_states[clean_track_key] = track_states


func _reset_book_progress(book: Dictionary, track_key: String) -> void:
	for level_number in range(1, _manager.get_track_level_count(track_key) + 1):
		if book.has(level_number):
			_set_book_level_completed(book, level_number, false)

func _export_book_progress(book: Dictionary, track_key: String) -> Array:
	var progress: Array = []
	for level_number in range(1, _manager.get_track_level_count(track_key) + 1):
		progress.append(_is_book_level_completed(book, level_number))
	return progress

func _import_book_progress(book: Dictionary, track_key: String, stored_progress: Variant) -> void:
	if stored_progress is Array:
		for level_index in range(min(stored_progress.size(), _manager.get_track_level_count(track_key))):
			var level_number := level_index + 1
			if book.has(level_number):
				_set_book_level_completed(book, level_number, bool(stored_progress[level_index]))

func _count_completed_levels(book: Dictionary, track_key: String) -> int:
	var completed := 0
	for level_number in range(1, _manager.get_track_level_count(track_key) + 1):
		if _is_book_level_completed(book, level_number):
			completed += 1
	return completed


func _is_book_level_completed(book: Dictionary, level_number: int) -> bool:
	var raw_level_progress: Variant = book.get(level_number, {})
	if not raw_level_progress is Dictionary:
		return false
	return bool((raw_level_progress as Dictionary).get(_manager.BOOK_LEVEL_COMPLETED_KEY, false))


func _set_book_level_completed(book: Dictionary, level_number: int, completed: bool) -> void:
	var raw_level_progress: Variant = book.get(level_number, {})
	if not raw_level_progress is Dictionary:
		return
	var level_progress: Dictionary = raw_level_progress
	level_progress[_manager.BOOK_LEVEL_COMPLETED_KEY] = completed
	book[level_number] = level_progress
