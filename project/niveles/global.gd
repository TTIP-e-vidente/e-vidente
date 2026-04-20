extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload("res://niveles/content/GameLevelContentCatalog.gd")
const GameStreakTracker := preload("res://niveles/progress/GameStreakTracker.gd")
const SaveRachaHelperScript := preload(
	"res://interface/save_local/progress/racha/SaveRachaHelper.gd"
)
const SaveCampanaHelperScript := preload(
	"res://interface/save_local/progress/campana/SaveCampanaHelper.gd"
)
const SaveEstadoHelperScript := preload(
	"res://interface/save_local/progress/estado/SaveEstadoHelper.gd"
)

const DEFAULT_PROGRESS_LABEL := "Tu progreso"

var current_level: int = 1

var _level_content: RefCounted
var _streak_save_helper: RefCounted
var _campaign_save_helper: RefCounted
var _partial_state_save_helper: RefCounted
var _completed_levels_by_track: Dictionary = {}
var _partial_level_state_by_track: Dictionary = {}
var _streak_state: Dictionary = {}


func _init() -> void:
	_level_content = GameLevelContentCatalogScript.new()
	_streak_save_helper = SaveRachaHelperScript.new()
	_campaign_save_helper = SaveCampanaHelperScript.new()
	_partial_state_save_helper = SaveEstadoHelperScript.new()
	reset_progress()


func get_current_level_number() -> int:
	return current_level


func set_current_level_number(level_number: int, track_key: String = "") -> void:
	var max_level: int = _level_content.get_max_track_level_count(GameTrackCatalog.DEFAULT_LEVEL_COUNT)
	var key: String = track_key.strip_edges()
	if not key.is_empty() and GameTrackCatalog.has_track(key):
		max_level = get_track_level_count(key)
	current_level = 1 if max_level <= 0 else clampi(level_number, 1, max_level)


func reset_progress() -> void:
	current_level = 1
	_completed_levels_by_track = {}
	_partial_level_state_by_track = {}
	_streak_state = {}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		_ensure_track_progress_exists(track_key)
		_partial_level_state_by_track[track_key] = {}

func mark_level_completed(track_key: String, level_number: int) -> void:
	var key := _get_valid_track_key(track_key)
	var level_index := _level_to_index(key, level_number)
	if level_index < 0:
		return
	_ensure_track_progress_exists(key)
	_completed_levels_by_track[key][level_index] = true

func is_level_unlocked(track_key: String, level_number: int) -> bool:
	var key := _get_valid_track_key(track_key)
	if key.is_empty():
		return level_number <= 1
	if level_number <= 1:
		return true
	return is_level_completed(key, level_number - 1)

func is_level_completed(track_key: String, level_number: int) -> bool:
	var key := _get_valid_track_key(track_key)
	var level_index := _level_to_index(key, level_number)
	if level_index < 0:
		return false
	_ensure_track_progress_exists(key)
	return _completed_levels_by_track[key][level_index]

func get_progress_summary() -> Dictionary:
	var summary: Dictionary = {
		"total": 0,
		"max_total": _level_content.get_total_level_count(GameTrackCatalog.get_total_level_count())
	}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var count: int = 0
		for level in range(1, get_track_level_count(track_key) + 1):
			if is_level_completed(track_key, level):
				count += 1
		summary[track_key] = count
		summary["total"] += count
	return summary

func format_progress_summary_text(summary: Dictionary = {}) -> String:
	var by_track: Dictionary = summary if not summary.is_empty() else get_progress_summary()
	var lines: Array[String] = []
	for track_definition in GameTrackCatalog.get_track_definitions():
		var key: String = str(track_definition.get("key", "")).strip_edges()
		if key.is_empty():
			continue
		var level_count: int = get_track_level_count(key)
		if level_count <= 0:
			continue
		var completed: int = int(by_track.get(key, 0))
		var label: String = GameTrackCatalog.get_track_summary_label(
			key,
			GameTrackCatalog.get_track_label(key, DEFAULT_PROGRESS_LABEL)
		)
		if label.is_empty():
			label = DEFAULT_PROGRESS_LABEL
		lines.append("%s %d/%d" % [label, min(level_count, completed + 1), level_count])
	return "\n".join(lines)


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var key := _get_valid_track_key(track_key)
	var level := _get_valid_level_number(key, level_number)
	if level <= 0:
		return {}
	return _partial_level_state_by_track.get(key, {}).get(level, {})

func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var key := _get_valid_track_key(track_key)
	var level := _get_valid_level_number(key, level_number)
	if level <= 0:
		return
	if not _partial_level_state_by_track.has(key):
		_partial_level_state_by_track[key] = {}
	if is_level_completed(key, level) or state.is_empty():
		_partial_level_state_by_track[key].erase(level)
	else:
		_partial_level_state_by_track[key][level] = state

func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var key := _get_valid_track_key(track_key)
	var level := _get_valid_level_number(key, level_number)
	if level <= 0:
		return
	if _partial_level_state_by_track.has(key):
		_partial_level_state_by_track[key].erase(level)


func get_streak_state() -> Dictionary:
	return GameStreakTracker.read(_streak_state)

func get_streak_view_model() -> Dictionary:
	return GameStreakTracker.view_model(get_streak_state())

func record_streak_activity(activity_type: String, metadata: Dictionary = {}) -> Dictionary:
	_streak_state = GameStreakTracker.record(get_streak_state(), activity_type, metadata)
	return _streak_state


func get_track_level_count(track_key: String = "") -> int:
	var fallback: int = GameTrackCatalog.get_track_level_count(
		track_key, GameTrackCatalog.DEFAULT_LEVEL_COUNT
	)
	return _level_content.get_track_level_count(track_key, fallback)

func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _level_content.get_chapter_run_count(track_key, level_number)

func get_chapter_run_definition(
	track_key: String, level_number: int, run_index: int = 1
) -> Dictionary:
	return _level_content.get_chapter_run_definition(track_key, level_number, run_index)


func export_progress() -> Dictionary:
	var snapshot: Dictionary = _campaign_save_helper.export_campana(
		_completed_levels_by_track, current_level, get_track_level_count
	)
	snapshot["partial_level_states"] = _partial_state_save_helper.export_estado(
		_partial_level_state_by_track
	)
	_streak_save_helper.export_streak(snapshot, _streak_state)
	return snapshot

func import_progress(snapshot: Dictionary) -> void:
	reset_progress()
	if snapshot.is_empty():
		return
	current_level = _campaign_save_helper.import_campana(
		snapshot, _completed_levels_by_track, get_track_level_count
	)
	_partial_level_state_by_track = _partial_state_save_helper.import_estado(
		snapshot.get("partial_level_states", {}),
		is_level_completed,
		get_track_level_count
	)
	_streak_state = _streak_save_helper.import_streak(snapshot)


func _get_valid_track_key(track_key: String) -> String:
	var key: String = track_key.strip_edges()
	if key.is_empty() or not GameTrackCatalog.has_track(key):
		return ""
	return key

func _level_to_index(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return -1
	var count := get_track_level_count(track_key)
	if count <= 0:
		return -1
	return clampi(level_number, 1, count) - 1

func _get_valid_level_number(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return 0
	var max_level: int = get_track_level_count(track_key)
	return 0 if max_level <= 0 else clampi(level_number, 1, max_level)

func _ensure_track_progress_exists(track_key: String) -> void:
	if _completed_levels_by_track.has(track_key):
		return
	var count := get_track_level_count(track_key)
	var flags: Array = []
	flags.resize(count)
	flags.fill(false)
	_completed_levels_by_track[track_key] = flags
