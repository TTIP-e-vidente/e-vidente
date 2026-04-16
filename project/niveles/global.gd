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
const TRACK_KEYS := GameTrackCatalog.TRACK_ORDER
const BOOK_LEVEL_COMPLETED_KEY := GameLevelContentCatalogScript.BOOK_LEVEL_COMPLETED_KEY
const DEFAULT_PROGRESS_LABEL := "Tu progreso"
const STREAK_SYSTEM_KEY := "streak"
const STREAK_CURRENT_COUNT_KEY := "current_count"
const STREAK_BEST_COUNT_KEY := "best_count"
const STREAK_LAST_ACTIVITY_DAY_KEY := "last_activity_day"
const STREAK_LAST_ACTIVITY_AT_KEY := "last_activity_at"
const STREAK_LAST_ACTIVITY_TYPE_KEY := "last_activity_type"
const STREAK_LAST_TRACK_KEY := "last_track_key"
const STREAK_DEFAULT_ACTIVITY_TYPE := "activity"
const STREAK_SECONDS_PER_DAY := 86400
const STREAK_STATUS_INACTIVE := "inactive"
const STREAK_STATUS_ACTIVE_TODAY := "active_today"
const STREAK_STATUS_PENDING_TODAY := "pending_today"
const STREAK_FEEDBACK_KEY_ACTIVATED := "activated"
const STREAK_FEEDBACK_KEY_SUSTAINED := "sustained"

var _level_content_catalog
var _progress_state_store
var campaign_progress_by_track: Dictionary = {}
var partial_level_state_by_track: Dictionary = {}
var progress_system_state_by_key: Dictionary = {}


func _init() -> void:
	_level_content_catalog = GameLevelContentCatalogScript.new()
	_progress_state_store = GameProgressStateStoreScript.new(self)
	_reset_runtime_progress_state()


# Contenido jugable.
func get_track_level_count(track_key: String = "") -> int:
	return _level_content_catalog.get_track_level_count(
		track_key,
		GameTrackCatalog.get_track_level_count(track_key, LEVELS_PER_BOOK)
	)


func get_max_track_level_count() -> int:
	return _level_content_catalog.get_max_track_level_count(LEVELS_PER_BOOK)


func get_total_level_count() -> int:
	return _level_content_catalog.get_total_level_count(
		GameTrackCatalog.get_total_level_count()
	)


func get_chapter_definition(track_key: String, level_number: int) -> Dictionary:
	return _level_content_catalog.get_chapter_definition(track_key, level_number)


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _level_content_catalog.get_chapter_run_count(track_key, level_number)


func get_chapter_run_definition(
	track_key: String,
	level_number: int,
	run_index: int = 1
) -> Dictionary:
	return _level_content_catalog.get_chapter_run_definition(
		track_key,
		level_number,
		run_index
	)


func filter_items_by_category(items: Array, category: String) -> Array:
	return _level_content_catalog.filter_items_by_category(items, category)


func resolve_texture(texture_ref: Variant) -> Texture2D:
	return _level_content_catalog.resolve_texture(texture_ref)


func build_default_campaign_progress_state() -> Dictionary:
	return _level_content_catalog.build_default_track_progress_state()


# Nivel actual.
func get_current_level_number() -> int:
	return current_level


func set_current_level_number(level_number: int, track_key: String = "") -> void:
	current_level = _clamp_level_number_for_track(track_key, level_number)


# Progreso de campaña visible por track y capitulo.
func get_campaign_progress_for_track(track_key: String) -> Dictionary:
	var track_key_to_use: String = _resolve_existing_track_key(track_key)
	if track_key_to_use.is_empty():
		return {}

	if not campaign_progress_by_track.has(track_key_to_use):
		campaign_progress_by_track[track_key_to_use] = (
			_level_content_catalog.build_default_track_progress_for_track(track_key_to_use)
		)

	var stored_track_progress: Variant = campaign_progress_by_track.get(
		track_key_to_use,
		{}
	)
	return stored_track_progress if stored_track_progress is Dictionary else {}


func mark_level_completed(track_key: String, level_number: int) -> void:
	var track_key_to_use: String = _resolve_existing_track_key(track_key)
	var level_number_to_use: int = _resolve_campaign_level_number(
		track_key_to_use,
		level_number
	)
	if level_number_to_use <= 0:
		return

	var track_progress: Dictionary = get_campaign_progress_for_track(track_key_to_use)
	var stored_level_progress: Variant = track_progress.get(level_number_to_use, {})
	if not stored_level_progress is Dictionary:
		return
	var level_progress_entry: Dictionary = stored_level_progress

	level_progress_entry[BOOK_LEVEL_COMPLETED_KEY] = true
	track_progress[level_number_to_use] = level_progress_entry


func is_level_unlocked(track_key: String, level_number: int) -> bool:
	var unlocked_level_number := _clamp_level_number_for_track(track_key, level_number)
	if unlocked_level_number <= 1:
		return true
	return is_level_completed(track_key, unlocked_level_number - 1)


func is_level_completed(track_key: String, level_number: int) -> bool:
	var track_key_to_use: String = _resolve_existing_track_key(track_key)
	var level_number_to_use: int = _resolve_campaign_level_number(
		track_key_to_use,
		level_number
	)
	if level_number_to_use <= 0:
		return false

	var track_progress: Dictionary = get_campaign_progress_for_track(track_key_to_use)
	var stored_level_progress: Variant = track_progress.get(level_number_to_use, {})
	if not stored_level_progress is Dictionary:
		return false
	var level_progress_entry: Dictionary = stored_level_progress

	return bool(level_progress_entry.get(BOOK_LEVEL_COMPLETED_KEY, false))


func reset_progress() -> void:
	_progress_state_store.reset_progress()


func export_progress() -> Dictionary:
	return _progress_state_store.export_progress()


func import_progress(progress: Dictionary) -> void:
	_progress_state_store.import_progress(progress)


func get_progress_summary() -> Dictionary:
	return _progress_state_store.get_progress_summary()


func format_progress_summary_text(summary: Dictionary = {}) -> String:
	var summary_by_track := summary if not summary.is_empty() else get_progress_summary()
	var summary_lines: Array[String] = []
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		if track_key.is_empty():
			continue

		var level_count: int = get_track_level_count(track_key)
		if level_count <= 0:
			continue

		var completed_levels: int = int(summary_by_track.get(track_key, 0))
		var visible_levels: int = min(level_count, completed_levels + 1)
		var summary_label := str(
			track_definition.get(
				"summary_label",
				track_definition.get("label", DEFAULT_PROGRESS_LABEL)
			)
		)
		summary_lines.append("%s %d/%d" % [summary_label, visible_levels, level_count])
	return "\n".join(summary_lines)


func get_streak_state() -> Dictionary:
	return _normalize_streak_state(get_progress_system_state(STREAK_SYSTEM_KEY))


func get_streak_view_model() -> Dictionary:
	var streak_state: Dictionary = get_streak_state()
	var current_count: int = int(streak_state.get(STREAK_CURRENT_COUNT_KEY, 0))
	var best_count: int = int(streak_state.get(STREAK_BEST_COUNT_KEY, 0))
	var activity_day: String = str(streak_state.get(STREAK_LAST_ACTIVITY_DAY_KEY, ""))
	var activity_type: String = str(streak_state.get(STREAK_LAST_ACTIVITY_TYPE_KEY, ""))
	var today_day_key: String = Time.get_date_string_from_system(false)
	var recorded_today: bool = activity_day == today_day_key
	var has_streak: bool = current_count > 0
	var pending_today: bool = has_streak and not recorded_today
	var status_key: String = STREAK_STATUS_PENDING_TODAY
	var status_title: String = "Racha pendiente hoy"
	var status_detail: String = "Tu racha sigue viva, pero todavia falta sostenerla hoy."
	var today_status_label: String = "Hoy falta"

	if not has_streak:
		status_key = STREAK_STATUS_INACTIVE
		status_title = "Sin racha activa"
		status_detail = "Completa una actividad para iniciar la racha."
		today_status_label = "Sin iniciar"
	elif recorded_today:
		status_key = STREAK_STATUS_ACTIVE_TODAY
		status_title = "Racha activa"
		status_detail = "Hoy ya registraste una actividad."
		today_status_label = "Hoy ok"

	var activity_type_label: String = "actividad valida"
	match activity_type:
		"level_completed":
			activity_type_label = "nivel completado"
		"question_session_completed":
			activity_type_label = "sesion de preguntas"

	var last_track_key: String = str(streak_state.get(STREAK_LAST_TRACK_KEY, "")).strip_edges()
	return {
		"current_count": current_count,
		"best_count": best_count,
		"has_streak": has_streak,
		"recorded_today": recorded_today,
		"pending_today": pending_today,
		"status_key": status_key,
		"status_title": status_title,
		"status_detail": status_detail,
		"today_status_label": today_status_label,
		"last_activity_day": activity_day,
		"last_activity_at": str(streak_state.get(STREAK_LAST_ACTIVITY_AT_KEY, "")),
		"last_activity_type": activity_type,
		"last_activity_type_label": activity_type_label,
		"last_track_key": last_track_key,
		"last_track_label": _resolve_track_label(last_track_key)
	}


func build_streak_feedback_event(
	previous_state: Dictionary,
	next_state: Dictionary = {}
) -> Dictionary:
	var normalized_previous_state: Dictionary = _normalize_streak_state(previous_state)
	var normalized_next_state: Dictionary = get_streak_state()
	if not next_state.is_empty():
		normalized_next_state = _normalize_streak_state(next_state)

	var today_day_key: String = Time.get_date_string_from_system(false)
	var previous_activity_day: String = str(
		normalized_previous_state.get(STREAK_LAST_ACTIVITY_DAY_KEY, "")
	).strip_edges()
	if previous_activity_day == today_day_key:
		return {"should_show": false}

	var next_activity_day: String = str(
		normalized_next_state.get(STREAK_LAST_ACTIVITY_DAY_KEY, "")
	).strip_edges()
	if next_activity_day != today_day_key:
		return {"should_show": false}

	var current_count: int = int(normalized_next_state.get(STREAK_CURRENT_COUNT_KEY, 0))
	if current_count <= 1:
		return {
			"should_show": true,
			"feedback_key": STREAK_FEEDBACK_KEY_ACTIVATED,
			"title": "Racha activada",
			"message": "Hoy empezaste una racha de 1 dia.",
			"current_count": 1,
			"best_count": int(normalized_next_state.get(STREAK_BEST_COUNT_KEY, 0))
		}

	return {
		"should_show": true,
		"feedback_key": STREAK_FEEDBACK_KEY_SUSTAINED,
		"title": "Hoy sostuviste tu racha",
		"message": "Vas %d %s seguidos." % [
			current_count,
			"dia" if current_count == 1 else "dias"
		],
		"current_count": current_count,
		"best_count": int(normalized_next_state.get(STREAK_BEST_COUNT_KEY, 0))
	}


func record_streak_activity(
	activity_type: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var updated_streak_state: Dictionary = get_streak_state()
	var activity_day: String = str(metadata.get("activity_day", "")).strip_edges()
	if not _is_valid_streak_day_key(activity_day):
		activity_day = Time.get_date_string_from_system(false)

	var activity_at_to_store: String = str(metadata.get("activity_at", "")).strip_edges()
	if activity_at_to_store.is_empty():
		activity_at_to_store = Time.get_datetime_string_from_system(false, true)
	if activity_at_to_store.get_slice(" ", 0) != activity_day:
		activity_at_to_store = "%s 00:00:00" % activity_day

	var activity_type_to_store: String = activity_type.strip_edges()
	if activity_type_to_store.is_empty():
		activity_type_to_store = STREAK_DEFAULT_ACTIVITY_TYPE

	var previous_current_count: int = int(updated_streak_state.get(STREAK_CURRENT_COUNT_KEY, 0))
	var previous_activity_day: String = str(
		updated_streak_state.get(STREAK_LAST_ACTIVITY_DAY_KEY, "")
	).strip_edges()
	var next_current_count: int = 1
	match _get_streak_day_difference(previous_activity_day, activity_day):
		0:
			next_current_count = previous_current_count
		1:
			next_current_count = previous_current_count + 1

	updated_streak_state[STREAK_CURRENT_COUNT_KEY] = next_current_count
	updated_streak_state[STREAK_BEST_COUNT_KEY] = max(
		int(updated_streak_state.get(STREAK_BEST_COUNT_KEY, 0)),
		next_current_count
	)
	updated_streak_state[STREAK_LAST_ACTIVITY_DAY_KEY] = activity_day
	updated_streak_state[STREAK_LAST_ACTIVITY_AT_KEY] = activity_at_to_store
	updated_streak_state[STREAK_LAST_ACTIVITY_TYPE_KEY] = activity_type_to_store
	updated_streak_state[STREAK_LAST_TRACK_KEY] = str(
		metadata.get("track_key", "")
	).strip_edges()

	set_progress_system_state(STREAK_SYSTEM_KEY, updated_streak_state)
	return updated_streak_state


func clear_streak_state() -> void:
	clear_progress_system_state(STREAK_SYSTEM_KEY)


func has_streak_activity_today() -> bool:
	return str(
		get_streak_state().get(STREAK_LAST_ACTIVITY_DAY_KEY, "")
	).strip_edges() == Time.get_date_string_from_system(false)


func get_progress_system_state(system_key: String) -> Dictionary:
	return _progress_state_store.get_progress_system_state(system_key)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	_progress_state_store.set_progress_system_state(system_key, system_state)


func clear_progress_system_state(system_key: String) -> void:
	_progress_state_store.clear_progress_system_state(system_key)


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	return _progress_state_store.get_partial_level_state(track_key, level_number)


func set_partial_level_state(
	track_key: String,
	level_number: int,
	state: Dictionary
) -> void:
	_progress_state_store.set_partial_level_state(track_key, level_number, state)


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	_progress_state_store.clear_partial_level_state(track_key, level_number)


func _reset_runtime_progress_state() -> void:
	campaign_progress_by_track = build_default_campaign_progress_state()
	partial_level_state_by_track = _progress_state_store.build_empty_partial_level_state_map()
	progress_system_state_by_key = {}


func _resolve_existing_track_key(track_key: String) -> String:
	var normalized_track_key := track_key.strip_edges()
	if normalized_track_key.is_empty() or not GameTrackCatalog.has_track(normalized_track_key):
		return ""
	return normalized_track_key


func _resolve_campaign_level_number(
	resolved_track_key: String,
	level_number: int
) -> int:
	if resolved_track_key.is_empty():
		return 0

	var max_level_number: int = get_track_level_count(resolved_track_key)
	if max_level_number <= 0:
		return 0

	return clampi(level_number, 1, max_level_number)


func _clamp_level_number_for_track(track_key: String, level_number: int) -> int:
	var resolved_track_key: String = _resolve_existing_track_key(track_key)
	var max_level_number := get_max_track_level_count()
	if not resolved_track_key.is_empty():
		max_level_number = get_track_level_count(resolved_track_key)
	if max_level_number <= 0:
		return 1
	return clampi(level_number, 1, max_level_number)


func _resolve_track_label(track_key: String) -> String:
	var resolved_track_key := _resolve_existing_track_key(track_key)
	if resolved_track_key.is_empty():
		return ""
	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(resolved_track_key)
	return str(track_definition.get("label", resolved_track_key)).strip_edges()


func _normalize_streak_state(raw_state: Variant) -> Dictionary:
	var normalized_state: Dictionary = {
		STREAK_CURRENT_COUNT_KEY: 0,
		STREAK_BEST_COUNT_KEY: 0,
		STREAK_LAST_ACTIVITY_DAY_KEY: "",
		STREAK_LAST_ACTIVITY_AT_KEY: "",
		STREAK_LAST_ACTIVITY_TYPE_KEY: "",
		STREAK_LAST_TRACK_KEY: ""
	}
	if not raw_state is Dictionary:
		return normalized_state

	var stored_streak_state: Dictionary = raw_state
	var current_count: int = max(0, int(stored_streak_state.get(STREAK_CURRENT_COUNT_KEY, 0)))
	var best_count: int = max(0, int(stored_streak_state.get(STREAK_BEST_COUNT_KEY, 0)))
	var last_activity_day: String = str(
		stored_streak_state.get(STREAK_LAST_ACTIVITY_DAY_KEY, "")
	).strip_edges()

	normalized_state[STREAK_BEST_COUNT_KEY] = max(best_count, current_count)
	if not _is_valid_streak_day_key(last_activity_day):
		return normalized_state

	var last_activity_at: String = str(
		stored_streak_state.get(STREAK_LAST_ACTIVITY_AT_KEY, "")
	).strip_edges()
	if last_activity_at.is_empty() or last_activity_at.get_slice(" ", 0) != last_activity_day:
		last_activity_at = "%s 00:00:00" % last_activity_day

	normalized_state[STREAK_CURRENT_COUNT_KEY] = current_count
	normalized_state[STREAK_LAST_ACTIVITY_DAY_KEY] = last_activity_day
	normalized_state[STREAK_LAST_ACTIVITY_AT_KEY] = last_activity_at
	normalized_state[STREAK_LAST_ACTIVITY_TYPE_KEY] = str(
		stored_streak_state.get(STREAK_LAST_ACTIVITY_TYPE_KEY, "")
	).strip_edges()
	normalized_state[STREAK_LAST_TRACK_KEY] = str(
		stored_streak_state.get(STREAK_LAST_TRACK_KEY, "")
	).strip_edges()
	return normalized_state


func _get_streak_day_difference(from_day_key: String, to_day_key: String) -> int:
	if from_day_key.is_empty():
		return -1

	var from_unix_time: int = int(Time.get_unix_time_from_datetime_string(from_day_key))
	var to_unix_time: int = int(Time.get_unix_time_from_datetime_string(to_day_key))
	return int((to_unix_time - from_unix_time) / float(STREAK_SECONDS_PER_DAY))


func _is_valid_streak_day_key(day_key: String) -> bool:
	if day_key.is_empty():
		return false

	var year_text: String = day_key.get_slice("-", 0)
	if not year_text.is_valid_int() or int(year_text) < 1:
		return false

	var unix_time: int = int(Time.get_unix_time_from_datetime_string(day_key))
	return Time.get_date_string_from_unix_time(unix_time) == day_key
