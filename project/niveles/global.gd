extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload(
	"res://niveles/content/GameLevelContentCatalog.gd"
)
const GameProgressStateStoreScript := preload(
	"res://niveles/progress/GameProgressStateStore.gd"
)

var player_cambiante
var is_dragging: Object
var manager_level
var current_level: int = 1

const LEVELS_PER_BOOK := GameTrackCatalog.DEFAULT_LEVEL_COUNT

var _content
var _progress


func _init() -> void:
	_content = GameLevelContentCatalogScript.new()
	_progress = GameProgressStateStoreScript.new(self, _content)


func get_track_level_count(track_key: String = "") -> int:
	return _content.get_track_level_count(
		track_key,
		GameTrackCatalog.get_track_level_count(
			track_key,
			GameTrackCatalog.DEFAULT_LEVEL_COUNT
		)
	)


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _content.get_chapter_run_count(track_key, level_number)


func get_chapter_run_definition(
	track_key: String,
	level_number: int,
	run_index: int = 1
) -> Dictionary:
	return _content.get_chapter_run_definition(
		track_key,
		level_number,
		run_index
	)


func get_current_level_number() -> int:
	return current_level


func set_current_level_number(level_number: int, track_key: String = "") -> void:
	var max_level_number: int = _content.get_max_track_level_count(
		GameTrackCatalog.DEFAULT_LEVEL_COUNT
	)
	var resolved_track_key: String = track_key.strip_edges()
	if not resolved_track_key.is_empty() and GameTrackCatalog.has_track(resolved_track_key):
		max_level_number = get_track_level_count(resolved_track_key)
	current_level = 1 if max_level_number <= 0 else clampi(level_number, 1, max_level_number)


func mark_level_completed(track_key: String, level_number: int) -> void:
	_progress.mark_level_completed(track_key, level_number)


func is_level_unlocked(track_key: String, level_number: int) -> bool:
	return _progress.is_level_unlocked(track_key, level_number)


func is_level_completed(track_key: String, level_number: int) -> bool:
	return _progress.is_level_completed(track_key, level_number)


func reset_progress() -> void:
	_progress.reset_progress()


func export_progress() -> Dictionary:
	return _progress.export_progress()


func import_progress(progress: Dictionary) -> void:
	_progress.import_progress(progress)


func get_progress_summary() -> Dictionary:
	return _progress.get_progress_summary()


func format_progress_summary_text(summary: Dictionary = {}) -> String:
	return _progress.format_progress_summary_text(summary)


func get_streak_state() -> Dictionary:
	return _progress.get_streak_state()


func get_streak_view_model() -> Dictionary:
	return _progress.get_streak_view_model()


func record_streak_activity(
	activity_type: String,
	metadata: Dictionary = {}
) -> Dictionary:
	return _progress.record_streak_activity(activity_type, metadata)


func get_progress_system_state(system_key: String) -> Dictionary:
	return _progress.get_progress_system_state(system_key)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	_progress.set_progress_system_state(system_key, system_state)


func clear_progress_system_state(system_key: String) -> void:
	_progress.clear_progress_system_state(system_key)


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	return _progress.get_partial_level_state(track_key, level_number)


func set_partial_level_state(
	track_key: String,
	level_number: int,
	state: Dictionary
) -> void:
	_progress.set_partial_level_state(track_key, level_number, state)


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	_progress.clear_partial_level_state(track_key, level_number)
