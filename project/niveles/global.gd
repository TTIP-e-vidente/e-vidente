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
const STREAK_SYSTEM_KEY := "streak"
const QUESTION_PROGRESS_SYSTEM_KEY := "question_progress"

var current_level: int = 1

var _level_content: RefCounted
var _streak_save_helper: RefCounted
var _campaign_save_helper: RefCounted
var _partial_state_save_helper: RefCounted
var _completed_levels_by_track: Dictionary = {}
var _partial_level_state_by_track: Dictionary = {}
var _streak_state: Dictionary = {}
var _extra_progress_system_states: Dictionary = {}
var _question_progress_by_track: Dictionary = {}
var _active_question_session: Dictionary = {}


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
	_extra_progress_system_states = {}
	_question_progress_by_track = {}
	_active_question_session = {}
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


# --- Preguntas del mapa ---

func mark_question_completed(track_key: String, question_key: String) -> void:
	var normalized_track_key: String = _get_valid_track_key(track_key)
	var normalized_question_key: String = question_key.strip_edges()
	if normalized_track_key.is_empty() or normalized_question_key.is_empty():
		return
	var progress_for_track: Dictionary = _question_progress_by_track.get(normalized_track_key, {})
	progress_for_track[normalized_question_key] = true
	_question_progress_by_track[normalized_track_key] = progress_for_track

func is_question_completed(track_key: String, question_key: String) -> bool:
	var normalized_track_key: String = _get_valid_track_key(track_key)
	var normalized_question_key: String = question_key.strip_edges()
	if normalized_track_key.is_empty() or normalized_question_key.is_empty():
		return false
	var raw_track_progress: Variant = _question_progress_by_track.get(normalized_track_key, {})
	if not raw_track_progress is Dictionary:
		return false
	return bool(raw_track_progress.get(normalized_question_key, false))

func set_active_question_session(session_state: Dictionary) -> void:
	_active_question_session = session_state.duplicate(true)

func get_active_question_session() -> Dictionary:
	return _active_question_session.duplicate(true)

func clear_active_question_session() -> void:
	_active_question_session = {}


# --- Estados extra de progreso ---

func set_progress_system_state(system_key: String, state: Dictionary) -> void:
	var normalized_system_key: String = system_key.strip_edges()
	if normalized_system_key.is_empty():
		return
	if state.is_empty():
		_extra_progress_system_states.erase(normalized_system_key)
		return
	_extra_progress_system_states[normalized_system_key] = state.duplicate(true)

func get_progress_system_state(system_key: String) -> Dictionary:
	var normalized_system_key: String = system_key.strip_edges()
	if normalized_system_key.is_empty():
		return {}
	var raw_state: Variant = _extra_progress_system_states.get(normalized_system_key, {})
	if raw_state is Dictionary:
		return (raw_state as Dictionary).duplicate(true)
	return {}


# --- Racha ---

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
	var snapshot: Dictionary = _export_campaign_progress()
	_export_partial_level_states(snapshot)
	_export_progress_system_states(snapshot)
	return snapshot


func _export_campaign_progress() -> Dictionary:
	return _campaign_save_helper.export_campana(
		_completed_levels_by_track, current_level, get_track_level_count
	)


func _export_partial_level_states(snapshot: Dictionary) -> void:
	snapshot["partial_level_states"] = _partial_state_save_helper.export_estado(
		_partial_level_state_by_track
	)


func _export_progress_system_states(snapshot: Dictionary) -> void:
	var systems_state: Dictionary = _build_progress_system_states_snapshot()
	if not systems_state.is_empty():
		snapshot["progress_system_states"] = systems_state

func import_progress(snapshot: Dictionary) -> void:
	reset_progress()
	if snapshot.is_empty():
		return
	_import_campaign_progress(snapshot)
	_import_partial_level_states(snapshot)
	_import_progress_system_states(snapshot.get("progress_system_states", {}))


func _import_campaign_progress(snapshot: Dictionary) -> void:
	current_level = _campaign_save_helper.import_campana(
		snapshot, _completed_levels_by_track, get_track_level_count
	)


func _import_partial_level_states(snapshot: Dictionary) -> void:
	_partial_level_state_by_track = _partial_state_save_helper.import_estado(
		snapshot.get("partial_level_states", {}),
		is_level_completed,
		get_track_level_count
	)


func _build_progress_system_states_snapshot() -> Dictionary:
	var systems_state: Dictionary = _duplicate_extra_progress_system_states()
	_append_streak_progress_state(systems_state)
	_append_question_progress_state(systems_state)
	return systems_state


func _duplicate_extra_progress_system_states() -> Dictionary:
	var systems_state: Dictionary = {}
	for system_key in _extra_progress_system_states.keys():
		var raw_state: Variant = _extra_progress_system_states.get(system_key, {})
		if raw_state is Dictionary:
			systems_state[str(system_key)] = (raw_state as Dictionary).duplicate(true)
	return systems_state


func _append_streak_progress_state(systems_state: Dictionary) -> void:
	var streak_wrapper: Dictionary = {}
	_streak_save_helper.export_streak(streak_wrapper, _streak_state)
	var streak_systems: Variant = streak_wrapper.get("progress_system_states", {})
	if streak_systems is Dictionary:
		systems_state.merge((streak_systems as Dictionary).duplicate(true), true)


func _append_question_progress_state(systems_state: Dictionary) -> void:
	if not _question_progress_by_track.is_empty():
		systems_state[QUESTION_PROGRESS_SYSTEM_KEY] = _question_progress_by_track.duplicate(true)


func _import_progress_system_states(raw_systems_state: Variant) -> void:
	if not raw_systems_state is Dictionary:
		return

	var systems_state: Dictionary = raw_systems_state
	_import_streak_progress_state(systems_state)
	_import_question_progress_state(systems_state)
	_import_custom_progress_system_states(systems_state)


func _import_streak_progress_state(systems_state: Dictionary) -> void:
	_streak_state = _streak_save_helper.import_streak({"progress_system_states": systems_state})


func _import_question_progress_state(systems_state: Dictionary) -> void:
	var question_progress_state: Variant = systems_state.get(QUESTION_PROGRESS_SYSTEM_KEY, {})
	if question_progress_state is Dictionary:
		_question_progress_by_track = (question_progress_state as Dictionary).duplicate(true)


func _import_custom_progress_system_states(systems_state: Dictionary) -> void:
	for system_key in systems_state.keys():
		var normalized_system_key: String = str(system_key).strip_edges()
		if normalized_system_key == STREAK_SYSTEM_KEY:
			continue
		if normalized_system_key == QUESTION_PROGRESS_SYSTEM_KEY:
			continue
		var raw_state: Variant = systems_state.get(system_key, {})
		if raw_state is Dictionary:
			_extra_progress_system_states[normalized_system_key] = (raw_state as Dictionary).duplicate(true)


func _get_valid_track_key(track_key: String) -> String:
	var key: String = track_key.strip_edges()
	if key.is_empty() or not GameTrackCatalog.has_track(key):
		return ""
	return key


func _level_to_index(track_key: String, level_number: int) -> int:
	if track_key.is_empty():
		return -1
	var count: int = get_track_level_count(track_key)
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
	var count: int = get_track_level_count(track_key)
	var flags: Array = []
	flags.resize(count)
	flags.fill(false)
	_completed_levels_by_track[track_key] = flags
