extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload("res://niveles/content/GameLevelContentCatalog.gd")
const GameCampaignProgressScript := preload("res://niveles/progress/GameCampaignProgress.gd")
const GamePartialLevelStateScript := preload("res://niveles/progress/GamePartialLevelState.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")
const GameStreakTracker := preload("res://niveles/progress/GameStreakTracker.gd")

const STREAK_KEY := "streak"

var current_level: int = 1

var _content
var _campaign
var _partial
var _streak: Dictionary = {}


func _init() -> void:
	_content = GameLevelContentCatalogScript.new()
	_campaign = GameCampaignProgressScript.new(self, _content)
	_partial = GamePartialLevelStateScript.new(_campaign, _content)


# --- Nivel actual ---

func get_current_level_number() -> int:
	return current_level

func set_current_level_number(level_number: int, track_key: String = "") -> void:
	var max_level: int = _content.get_max_track_level_count(GameTrackCatalog.DEFAULT_LEVEL_COUNT)
	var key: String = track_key.strip_edges()
	if not key.is_empty() and GameTrackCatalog.has_track(key):
		max_level = get_track_level_count(key)
	current_level = 1 if max_level <= 0 else clampi(level_number, 1, max_level)


# --- Campaña ---

func mark_level_completed(track_key: String, level_number: int) -> void:
	_campaign.mark_completed(track_key, level_number)

func is_level_unlocked(track_key: String, level_number: int) -> bool:
	return _campaign.is_unlocked(track_key, level_number)

func is_level_completed(track_key: String, level_number: int) -> bool:
	return _campaign.is_completed(track_key, level_number)

func get_campaign_progress_for_track(track_key: String) -> Dictionary:
	return _campaign.get_track_progress(track_key)

func get_progress_summary() -> Dictionary:
	return _campaign.get_summary()

func format_progress_summary_text(summary: Dictionary = {}) -> String:
	return _campaign.format_summary_text(summary)


# --- Estado parcial de nivel ---

func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	return _partial.get_state(track_key, level_number)

func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	_partial.set_state(track_key, level_number, state)

func clear_partial_level_state(track_key: String, level_number: int) -> void:
	_partial.clear_state(track_key, level_number)


# --- Racha ---

func get_streak_state() -> Dictionary:
	return GameStreakTracker.read(_streak)

func get_streak_view_model() -> Dictionary:
	return GameStreakTracker.view_model(get_streak_state())

func record_streak_activity(activity_type: String, metadata: Dictionary = {}) -> Dictionary:
	_streak = GameStreakTracker.record(get_streak_state(), activity_type, metadata)
	return _streak


# --- Catalogo de niveles ---

func get_track_level_count(track_key: String = "") -> int:
	var fallback: int = GameTrackCatalog.get_track_level_count(track_key, GameTrackCatalog.DEFAULT_LEVEL_COUNT)
	return _content.get_track_level_count(track_key, fallback)

func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _content.get_chapter_run_count(track_key, level_number)

func get_chapter_run_definition(track_key: String, level_number: int, run_index: int = 1) -> Dictionary:
	return _content.get_chapter_run_definition(track_key, level_number, run_index)


# --- Export / import (solo lo usa SaveManager) ---

func reset_progress() -> void:
	_campaign.reset()
	_partial.reset()
	_streak = {}

func export_progress() -> Dictionary:
	var snapshot: Dictionary = _campaign.export_flags()
	snapshot[GameProgressKeys.PARTIAL_LEVEL_STATES_KEY] = _partial.export_states()
	if not _streak.is_empty():
		snapshot[GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY] = {STREAK_KEY: _streak.duplicate(true)}
	return snapshot

func import_progress(snapshot: Dictionary) -> void:
	reset_progress()
	if snapshot.is_empty():
		return
	_campaign.import_flags(snapshot)
	_partial.import_states(snapshot.get(GameProgressKeys.PARTIAL_LEVEL_STATES_KEY, {}))
	var systems: Variant = snapshot.get(GameProgressKeys.PROGRESS_SYSTEM_STATES_KEY, {})
	var streak: Variant = systems.get(STREAK_KEY, {}) if systems is Dictionary else {}
	if streak is Dictionary:
		_streak = (streak as Dictionary).duplicate(true)
