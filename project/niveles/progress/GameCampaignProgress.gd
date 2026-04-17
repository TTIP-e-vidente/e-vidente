extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const BOOK_LEVEL_COMPLETED_KEY := "completed"
const DEFAULT_PROGRESS_LABEL := "Tu progreso"

var _campaign_progress: Dictionary = {}
var _global_state
var _content


func _init(global_state, content) -> void:
	_global_state = global_state
	_content = content
	reset()


func reset() -> void:
	_campaign_progress = _content.build_default_track_progress_state()
	_global_state.set_current_level_number(1)


func get_track_progress(track_key: String) -> Dictionary:
	var key: String = _validate_track(track_key)
	if key.is_empty():
		return {}
	if not _campaign_progress.has(key):
		_campaign_progress[key] = _content.build_default_track_progress_for_track(key)
	return _campaign_progress.get(key, {})


func mark_completed(track_key: String, level_number: int) -> void:
	var key: String = _validate_track(track_key)
	var level: int = _clamp_level(key, level_number)
	if level <= 0:
		return
	var track_progress: Dictionary = get_track_progress(key)
	var level_progress: Dictionary = track_progress.get(level, {})
	level_progress[BOOK_LEVEL_COMPLETED_KEY] = true
	track_progress[level] = level_progress


func is_unlocked(track_key: String, level_number: int) -> bool:
	var key: String = _validate_track(track_key)
	if key.is_empty():
		return level_number <= 1
	var level: int = clampi(level_number, 1, _get_level_count(key))
	if level <= 1:
		return true
	return is_completed(key, level - 1)


func is_completed(track_key: String, level_number: int) -> bool:
	var key: String = _validate_track(track_key)
	var level: int = _clamp_level(key, level_number)
	if level <= 0:
		return false
	var level_progress: Dictionary = get_track_progress(key).get(level, {})
	return bool(level_progress.get(BOOK_LEVEL_COMPLETED_KEY, false))


func get_summary() -> Dictionary:
	var summary: Dictionary = {
		"total": 0,
		"max_total": _content.get_total_level_count(GameTrackCatalog.get_total_level_count())
	}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var count: int = 0
		for level in range(1, _get_level_count(track_key) + 1):
			if is_completed(track_key, level):
				count += 1
		summary[track_key] = count
		summary["total"] += count
	return summary


func format_summary_text(summary: Dictionary = {}) -> String:
	var by_track: Dictionary = summary if not summary.is_empty() else get_summary()
	var lines: Array[String] = []
	for track_def in GameTrackCatalog.get_track_definitions():
		var key: String = str(track_def.get("key", "")).strip_edges()
		if key.is_empty():
			continue
		var level_count: int = _get_level_count(key)
		if level_count <= 0:
			continue
		var completed: int = int(by_track.get(key, 0))
		var label: String = str(track_def.get("summary_label", track_def.get("label", DEFAULT_PROGRESS_LABEL))).strip_edges()
		if label.is_empty():
			label = DEFAULT_PROGRESS_LABEL
		lines.append("%s %d/%d" % [label, min(level_count, completed + 1), level_count])
	return "\n".join(lines)


func export_flags() -> Dictionary:
	var result: Dictionary = {"current_level": _global_state.get_current_level_number()}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var flags: Array = []
		for level in range(1, _get_level_count(track_key) + 1):
			flags.append(is_completed(track_key, level))
		result[track_key] = flags
	return result


func import_flags(snapshot: Dictionary) -> void:
	_global_state.set_current_level_number(int(snapshot.get("current_level", 1)))
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var raw_flags: Variant = snapshot.get(track_key, [])
		if not raw_flags is Array:
			continue
		var flags: Array = raw_flags as Array
		var track_progress: Dictionary = get_track_progress(track_key)
		for i in range(min(flags.size(), _get_level_count(track_key))):
			var level_progress: Dictionary = track_progress.get(i + 1, {})
			level_progress[BOOK_LEVEL_COMPLETED_KEY] = bool(flags[i])
			track_progress[i + 1] = level_progress


func _validate_track(track_key: String) -> String:
	var key: String = track_key.strip_edges()
	if key.is_empty() or not GameTrackCatalog.has_track(key):
		return ""
	return key


func _clamp_level(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return 0
	var max_level: int = _get_level_count(track_key)
	return 0 if max_level <= 0 else clampi(level_number, 1, max_level)


func _get_level_count(track_key: String) -> int:
	var fallback: int = GameTrackCatalog.get_track_level_count(track_key, GameTrackCatalog.DEFAULT_LEVEL_COUNT)
	return _content.get_track_level_count(track_key, fallback)
