extends RefCounted

const CURRENT_COUNT_KEY := "current_count"
const BEST_COUNT_KEY := "best_count"
const LAST_ACTIVITY_DAY_KEY := "last_activity_day"
const LAST_ACTIVITY_AT_KEY := "last_activity_at"
const LAST_ACTIVITY_TYPE_KEY := "last_activity_type"
const LAST_TRACK_KEY := "last_track_key"

const DEFAULT_ACTIVITY_TYPE := "activity"
const SECONDS_PER_DAY := 86400

const STATUS_INACTIVE := "inactive"
const STATUS_ACTIVE_TODAY := "active_today"
const STATUS_PENDING_TODAY := "pending_today"
const FEEDBACK_KEY_ACTIVATED := "activated"
const FEEDBACK_KEY_SUSTAINED := "sustained"


func build_default_state() -> Dictionary:
	return {
		CURRENT_COUNT_KEY: 0,
		BEST_COUNT_KEY: 0,
		LAST_ACTIVITY_DAY_KEY: "",
		LAST_ACTIVITY_AT_KEY: "",
		LAST_ACTIVITY_TYPE_KEY: "",
		LAST_TRACK_KEY: ""
	}


func normalize_state(raw_state: Variant) -> Dictionary:
	var normalized_state := build_default_state()
	if not raw_state is Dictionary:
		return normalized_state

	var source_state: Dictionary = raw_state
	var current_count: int = max(0, int(source_state.get(CURRENT_COUNT_KEY, 0)))
	var best_count: int = max(0, int(source_state.get(BEST_COUNT_KEY, 0)))
	var last_activity_day: String = str(
		source_state.get(LAST_ACTIVITY_DAY_KEY, "")
	).strip_edges()

	if not _is_valid_day_key(last_activity_day):
		normalized_state[BEST_COUNT_KEY] = max(best_count, current_count)
		return normalized_state

	normalized_state[CURRENT_COUNT_KEY] = current_count
	normalized_state[BEST_COUNT_KEY] = max(best_count, current_count)
	normalized_state[LAST_ACTIVITY_DAY_KEY] = last_activity_day
	normalized_state[LAST_ACTIVITY_AT_KEY] = _normalize_timestamp(
		last_activity_day,
		str(source_state.get(LAST_ACTIVITY_AT_KEY, "")).strip_edges()
	)
	normalized_state[LAST_ACTIVITY_TYPE_KEY] = str(
		source_state.get(LAST_ACTIVITY_TYPE_KEY, "")
	).strip_edges()
	normalized_state[LAST_TRACK_KEY] = str(source_state.get(LAST_TRACK_KEY, "")).strip_edges()
	return normalized_state


func record_activity(
	raw_state: Variant,
	activity_type: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var next_state: Dictionary = normalize_state(raw_state)
	var activity_day: String = _resolve_activity_day(metadata)
	var activity_at: String = _resolve_activity_timestamp(metadata, activity_day)
	var clean_activity_type: String = activity_type.strip_edges()
	if clean_activity_type.is_empty():
		clean_activity_type = DEFAULT_ACTIVITY_TYPE

	var next_current_count: int = _resolve_next_current_count(next_state, activity_day)
	next_state[CURRENT_COUNT_KEY] = next_current_count
	next_state[BEST_COUNT_KEY] = max(
		int(next_state.get(BEST_COUNT_KEY, 0)),
		next_current_count
	)
	next_state[LAST_ACTIVITY_DAY_KEY] = activity_day
	next_state[LAST_ACTIVITY_AT_KEY] = activity_at
	next_state[LAST_ACTIVITY_TYPE_KEY] = clean_activity_type
	next_state[LAST_TRACK_KEY] = str(metadata.get("track_key", "")).strip_edges()
	return next_state


func is_activity_recorded_today(raw_state: Variant) -> bool:
	var state: Dictionary = normalize_state(raw_state)
	return str(state.get(LAST_ACTIVITY_DAY_KEY, "")) == _today_day_key()


func build_view_model(raw_state: Variant) -> Dictionary:
	var state: Dictionary = normalize_state(raw_state)
	var current_count: int = int(state.get(CURRENT_COUNT_KEY, 0))
	var best_count: int = int(state.get(BEST_COUNT_KEY, 0))
	var recorded_today: bool = is_activity_recorded_today(state)
	var has_streak: bool = current_count > 0
	var status_view: Dictionary = _build_status_view(has_streak, recorded_today)

	return {
		"current_count": current_count,
		"best_count": best_count,
		"has_streak": has_streak,
		"recorded_today": recorded_today,
		"pending_today": has_streak and not recorded_today,
		"status_key": str(status_view.get("status_key", STATUS_INACTIVE)),
		"status_title": str(status_view.get("status_title", "Sin racha activa")),
		"status_detail": str(
			status_view.get("status_detail", "Completa una actividad valida para iniciar la racha.")
		),
		"today_status_label": str(status_view.get("today_status_label", "Sin iniciar")),
		"last_activity_day": str(state.get(LAST_ACTIVITY_DAY_KEY, "")),
		"last_activity_at": str(state.get(LAST_ACTIVITY_AT_KEY, "")),
		"last_activity_type": str(state.get(LAST_ACTIVITY_TYPE_KEY, "")),
		"last_activity_type_label": _format_activity_type_label(
			str(state.get(LAST_ACTIVITY_TYPE_KEY, ""))
		),
		"last_track_key": str(state.get(LAST_TRACK_KEY, ""))
	}


func build_feedback_event(previous_raw_state: Variant, next_raw_state: Variant) -> Dictionary:
	var previous_state: Dictionary = normalize_state(previous_raw_state)
	var next_state: Dictionary = normalize_state(next_raw_state)
	if not _should_show_feedback(previous_state, next_state):
		return _build_hidden_feedback_event()

	var current_count: int = int(next_state.get(CURRENT_COUNT_KEY, 0))
	if current_count <= 1:
		return _build_activation_feedback_event(next_state)
	return _build_sustained_feedback_event(current_count, next_state)


func format_summary_text(raw_state: Variant) -> String:
	var view_model: Dictionary = build_view_model(raw_state)
	if not bool(view_model.get("has_streak", false)):
		return "Racha diaria: sin actividad valida todavia"

	var current_count: int = int(view_model.get("current_count", 0))
	var best_count: int = int(view_model.get("best_count", 0))
	var today_status: String = "Hoy: pendiente"
	if bool(view_model.get("recorded_today", false)):
		today_status = "Hoy: completada"

	return "\n".join([
		"Racha diaria: %d %s" % [current_count, _format_day_label(current_count)],
		"Mejor racha: %d %s" % [best_count, _format_day_label(best_count)],
		today_status
	])


func _build_status_view(has_streak: bool, recorded_today: bool) -> Dictionary:
	if not has_streak:
		return {
			"status_key": STATUS_INACTIVE,
			"status_title": "Sin racha activa",
			"status_detail": "Completa una actividad valida para iniciar la racha.",
			"today_status_label": "Sin iniciar"
		}
	if recorded_today:
		return {
			"status_key": STATUS_ACTIVE_TODAY,
			"status_title": "Racha activa",
			"status_detail": "Hoy ya registraste una actividad valida.",
			"today_status_label": "Hoy ok"
		}
	return {
		"status_key": STATUS_PENDING_TODAY,
		"status_title": "Racha pendiente hoy",
		"status_detail": "Tu racha sigue viva, pero todavia falta sostenerla hoy.",
		"today_status_label": "Hoy falta"
	}


func _should_show_feedback(previous_state: Dictionary, next_state: Dictionary) -> bool:
	return not is_activity_recorded_today(previous_state) and is_activity_recorded_today(next_state)


func _build_hidden_feedback_event() -> Dictionary:
	return {
		"should_show": false
	}


func _build_activation_feedback_event(next_state: Dictionary) -> Dictionary:
	return {
		"should_show": true,
		"feedback_key": FEEDBACK_KEY_ACTIVATED,
		"title": "Racha activada",
		"message": "Hoy empezaste una racha de 1 dia.",
		"current_count": 1,
		"best_count": int(next_state.get(BEST_COUNT_KEY, 0))
	}


func _build_sustained_feedback_event(current_count: int, next_state: Dictionary) -> Dictionary:
	return {
		"should_show": true,
		"feedback_key": FEEDBACK_KEY_SUSTAINED,
		"title": "Hoy sostuviste tu racha",
		"message": "Vas %d %s seguidos." % [current_count, _format_day_label(current_count)],
		"current_count": current_count,
		"best_count": int(next_state.get(BEST_COUNT_KEY, 0))
	}


func _resolve_activity_day(metadata: Dictionary) -> String:
	var activity_day: String = str(metadata.get("activity_day", "")).strip_edges()
	if not _is_valid_day_key(activity_day):
		return _today_day_key()
	return activity_day


func _resolve_activity_timestamp(metadata: Dictionary, activity_day: String) -> String:
	var activity_at: String = str(metadata.get("activity_at", "")).strip_edges()
	if activity_at.is_empty():
		var raw_activity_day: String = str(metadata.get("activity_day", "")).strip_edges()
		if raw_activity_day.is_empty():
			return Time.get_datetime_string_from_system(false, true)
		return _build_day_start_timestamp(activity_day)
	return _normalize_timestamp(activity_day, activity_at)


func _resolve_next_current_count(state: Dictionary, activity_day: String) -> int:
	var current_count: int = int(state.get(CURRENT_COUNT_KEY, 0))
	var last_activity_day: String = str(state.get(LAST_ACTIVITY_DAY_KEY, "")).strip_edges()
	if last_activity_day.is_empty():
		return 1

	var day_difference: int = _get_day_difference(last_activity_day, activity_day)
	if day_difference == 0:
		return current_count
	if day_difference == 1:
		return current_count + 1
	return 1


func _normalize_timestamp(activity_day: String, activity_at: String) -> String:
	if activity_at.is_empty():
		return _build_day_start_timestamp(activity_day)
	if activity_at.get_slice(" ", 0) != activity_day:
		return _build_day_start_timestamp(activity_day)
	return activity_at


func _build_day_start_timestamp(activity_day: String) -> String:
	return "%s 00:00:00" % activity_day


func _today_day_key() -> String:
	return Time.get_date_string_from_system(false)


func _is_valid_day_key(day_key: String) -> bool:
	if day_key.is_empty():
		return false

	var year_text: String = day_key.get_slice("-", 0)
	if not year_text.is_valid_int() or int(year_text) < 1:
		return false

	var unix_time: int = int(Time.get_unix_time_from_datetime_string(day_key))
	return Time.get_date_string_from_unix_time(unix_time) == day_key


func _get_day_difference(from_day_key: String, to_day_key: String) -> int:
	var from_unix_time: int = int(Time.get_unix_time_from_datetime_string(from_day_key))
	var to_unix_time: int = int(Time.get_unix_time_from_datetime_string(to_day_key))
	return int((to_unix_time - from_unix_time) / SECONDS_PER_DAY)


func _format_activity_type_label(activity_type: String) -> String:
	match activity_type:
		"level_completed":
			return "nivel completado"
		"question_session_completed":
			return "sesion de preguntas"
		_:
			return "actividad valida"


func _format_day_label(count: int) -> String:
	return "dia" if count == 1 else "dias"
