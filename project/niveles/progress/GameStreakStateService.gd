extends RefCounted

const CURRENT_COUNT_KEY := "current_count"
const BEST_COUNT_KEY := "best_count"
const LAST_ACTIVITY_DAY_KEY := "last_activity_day"
const LAST_ACTIVITY_AT_KEY := "last_activity_at"
const LAST_ACTIVITY_TYPE_KEY := "last_activity_type"
const LAST_TRACK_KEY := "last_track_key"
const DEFAULT_ACTIVITY_TYPE := "activity"


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
	var state := build_default_state()
	if not raw_state is Dictionary:
		return state

	var source_state: Dictionary = raw_state
	state[CURRENT_COUNT_KEY] = max(0, int(source_state.get(CURRENT_COUNT_KEY, 0)))
	state[BEST_COUNT_KEY] = max(0, int(source_state.get(BEST_COUNT_KEY, 0)))

	var saved_day := str(source_state.get(LAST_ACTIVITY_DAY_KEY, "")).strip_edges()
	if _parse_day_key(saved_day).is_empty():
		state[CURRENT_COUNT_KEY] = 0
		state[BEST_COUNT_KEY] = max(
			int(state.get(BEST_COUNT_KEY, 0)),
			int(state.get(CURRENT_COUNT_KEY, 0))
		)
		return state

	state[LAST_ACTIVITY_DAY_KEY] = saved_day

	var saved_timestamp := str(source_state.get(LAST_ACTIVITY_AT_KEY, "")).strip_edges()
	if saved_timestamp.is_empty():
		state[LAST_ACTIVITY_AT_KEY] = "%s 00:00:00" % saved_day
	elif saved_timestamp.get_slice(" ", 0) == saved_day:
		state[LAST_ACTIVITY_AT_KEY] = saved_timestamp
	else:
		state[LAST_ACTIVITY_AT_KEY] = "%s 00:00:00" % saved_day

	state[LAST_ACTIVITY_TYPE_KEY] = str(
		source_state.get(LAST_ACTIVITY_TYPE_KEY, "")
	).strip_edges()
	state[LAST_TRACK_KEY] = str(source_state.get(LAST_TRACK_KEY, "")).strip_edges()
	state[BEST_COUNT_KEY] = max(
		int(state.get(BEST_COUNT_KEY, 0)),
		int(state.get(CURRENT_COUNT_KEY, 0))
	)
	return state


func record_activity(
	raw_state: Variant,
	activity_type: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var state: Dictionary = normalize_state(raw_state)

	var raw_activity_day := str(metadata.get("activity_day", "")).strip_edges()
	var activity_day := raw_activity_day
	if _parse_day_key(activity_day).is_empty():
		activity_day = _today_day_key()

	var activity_at := str(metadata.get("activity_at", "")).strip_edges()
	if activity_at.is_empty():
		if raw_activity_day.is_empty():
			activity_at = Time.get_datetime_string_from_system(false, true)
		else:
			activity_at = "%s 00:00:00" % activity_day
	elif activity_at.get_slice(" ", 0) != activity_day:
		activity_at = "%s 00:00:00" % activity_day

	var clean_activity_type := activity_type.strip_edges()
	if clean_activity_type.is_empty():
		clean_activity_type = DEFAULT_ACTIVITY_TYPE

	var last_activity_day := str(state.get(LAST_ACTIVITY_DAY_KEY, "")).strip_edges()
	if last_activity_day.is_empty():
		state[CURRENT_COUNT_KEY] = 1
	elif last_activity_day == activity_day:
		pass
	elif _next_day_key(last_activity_day) == activity_day:
		state[CURRENT_COUNT_KEY] = int(state.get(CURRENT_COUNT_KEY, 0)) + 1
	else:
		state[CURRENT_COUNT_KEY] = 1

	state[BEST_COUNT_KEY] = max(
		int(state.get(BEST_COUNT_KEY, 0)),
		int(state.get(CURRENT_COUNT_KEY, 0))
	)
	state[LAST_ACTIVITY_DAY_KEY] = activity_day
	state[LAST_ACTIVITY_AT_KEY] = activity_at
	state[LAST_ACTIVITY_TYPE_KEY] = clean_activity_type
	state[LAST_TRACK_KEY] = str(metadata.get("track_key", "")).strip_edges()
	return state


func is_activity_recorded_today(raw_state: Variant) -> bool:
	var normalized_state: Dictionary = normalize_state(raw_state)
	return str(normalized_state.get(LAST_ACTIVITY_DAY_KEY, "")) == _today_day_key()


func format_summary_text(raw_state: Variant) -> String:
	var normalized_state: Dictionary = normalize_state(raw_state)
	var current_count: int = int(normalized_state.get(CURRENT_COUNT_KEY, 0))
	if current_count <= 0:
		return "Racha diaria: sin actividad valida todavia"

	var best_count: int = int(normalized_state.get(BEST_COUNT_KEY, 0))
	var today_status := "Hoy: pendiente"
	if is_activity_recorded_today(normalized_state):
		today_status = "Hoy: completada"
	return "\n".join([
		"Racha diaria: %d %s" % [current_count, _day_label(current_count)],
		"Mejor racha: %d %s" % [best_count, _day_label(best_count)],
		today_status
	])


func _today_day_key() -> String:
	return Time.get_datetime_string_from_system(false, true).get_slice(" ", 0)


func _parse_day_key(day_key: String) -> Array:
	var parts := day_key.split("-")
	if parts.size() != 3:
		return []

	var year: int = int(parts[0])
	var month: int = int(parts[1])
	var day: int = int(parts[2])
	if year < 1 or month < 1 or month > 12:
		return []

	var days_in_month: int = _days_in_month(year, month)
	if day < 1 or day > days_in_month:
		return []
	return [year, month, day]


func _next_day_key(day_key: String) -> String:
	var parsed_day: Array = _parse_day_key(day_key)
	if parsed_day.is_empty():
		return ""

	var year: int = int(parsed_day[0])
	var month: int = int(parsed_day[1])
	var day: int = int(parsed_day[2]) + 1
	if day > _days_in_month(year, month):
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1
	return "%04d-%02d-%02d" % [year, month, day]


func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 0


func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0


func _day_label(count: int) -> String:
	return "dia" if count == 1 else "dias"