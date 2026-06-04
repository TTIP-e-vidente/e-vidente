extends RefCounted

# GameStreakTracker.gd
# Calcula la racha solo cuando se registra una actividad real.
# Leer o abrir pantallas no debe incrementar ni recalcular dias.

const SECONDS_PER_DAY := 86400
const WARNING_START_HOUR_LOCAL := 20


# --- Estado estable ---------------------------------------------------------

static func leer(raw_state: Variant) -> Dictionary:
	if not raw_state is Dictionary:
		return _empty_streak_state()

	var stored: Dictionary = raw_state
	var last_day: String = str(stored.get("last_activity_day", "")).strip_edges()
	var current_count: int = max(0, int(stored.get("current_count", 0)))
	var best_count: int = max(0, int(stored.get("best_count", 0)))

	# Si la fecha guardada no es valida, la racha esta rota.
	if not _is_valid_date(last_day):
		return _empty_streak_state()

	best_count = max(best_count, current_count)
	return {
		"current_count": current_count,
		"best_count": best_count,
		"last_activity_day": last_day,
		"last_activity_type": str(stored.get("last_activity_type", "")).strip_edges(),
		"last_track_key": str(stored.get("last_track_key", "")).strip_edges()
	}


# --- Actividad --------------------------------------------------------------

static func registrar(
	streak_state: Dictionary,
	activity_type: String,
	metadata: Dictionary
) -> Dictionary:
	var today: String = Time.get_date_string_from_system(false)
	var last_day: String = str(streak_state.get("last_activity_day", ""))
	var old_count: int = int(streak_state.get("current_count", 0))

	var new_count: int = 1
	if last_day == today:
		new_count = old_count
	elif _days_between(last_day, today) == 1:
		new_count = old_count + 1

	var clean_type: String = activity_type.strip_edges()
	return {
		"current_count": new_count,
		"best_count": max(int(streak_state.get("best_count", 0)), new_count),
		"last_activity_day": today,
		"last_activity_type": "activity" if clean_type.is_empty() else clean_type,
		"last_track_key": str(metadata.get("track_key", "")).strip_edges()
	}


# --- Datos para UI ----------------------------------------------------------

static func _resolver_estado_visual(
	streak_state: Dictionary,
	current_date: String = "",
	current_hour: int = -1
) -> String:
	var current_count: int = int(streak_state.get("current_count", 0))
	if current_count <= 0:
		return "inactive"

	var today: String = _resolver_fecha_actual(current_date)
	var last_day: String = str(streak_state.get("last_activity_day", ""))
	if last_day == today:
		return "active"
	if _days_between(last_day, today) == 1:
		return "warning" if _esta_en_ventana_de_warning(current_hour) else "active"
	return "inactive"


static func modelo_vista(
	streak_state: Dictionary,
	current_date: String = "",
	current_hour: int = -1
) -> Dictionary:
	var current_count: int = int(streak_state.get("current_count", 0))
	var best_count: int = int(streak_state.get("best_count", 0))
	var last_day: String = str(streak_state.get("last_activity_day", ""))
	var today: String = _resolver_fecha_actual(current_date)
	var visual_state: String = _resolver_estado_visual(streak_state, today, current_hour)

	if current_count <= 0:
		return {
			"current_count": 0,
			"best_count": best_count,
			"status_key": "inactive",
			"status_title": "Sin racha activa",
			"status_detail": "Completa una actividad para iniciar la racha.",
			"streak_state": visual_state
		}

	if last_day == today:
		return {
			"current_count": current_count,
			"best_count": best_count,
			"status_key": "active_today",
			"status_title": "Racha activa",
			"status_detail": "Hoy ya registraste una actividad.",
			"streak_state": visual_state
		}

	return {
		"current_count": current_count,
		"best_count": best_count,
		"status_key": "pending_today",
		"status_title": "Racha pendiente hoy",
		"status_detail": "Tu racha sigue viva, pero todavia falta sostenerla hoy.",
		"streak_state": visual_state
	}


# --- Feedback post-partida --------------------------------------------------

static func construir_feedback(
	previous_state: Dictionary,
	updated_state: Dictionary,
	only_first_today: bool = false
) -> Dictionary:
	if updated_state.is_empty():
		return {"should_show": false}

	if only_first_today:
		var today: String = Time.get_date_string_from_system(false)
		var already_played_today: bool = str(previous_state.get("last_activity_day", "")) == today
		var streak_updated_today: bool = str(updated_state.get("last_activity_day", "")) == today
		if already_played_today or not streak_updated_today:
			return {"should_show": false}

	var count: int = max(0, int(updated_state.get("current_count", 0)))
	if count <= 0:
		return {"should_show": false}
	var best: int = max(count, int(updated_state.get("best_count", 0)))

	if count == 1:
		return {
			"should_show": true,
			"feedback_key": "activated",
			"title": "Racha activada",
			"message": "Hoy empezaste una racha de 1 dia.",
			"current_count": 1,
			"best_count": best
		}

	return {
		"should_show": true,
		"feedback_key": "sustained",
		"title": "Hoy sostuviste tu racha",
		"message": "Vas %d %s seguidos." % [count, "dia" if count == 1 else "dias"],
		"current_count": count,
		"best_count": best
	}


# --- Helpers internos -------------------------------------------------------

static func _empty_streak_state() -> Dictionary:
	return {
		"current_count": 0,
		"best_count": 0,
		"last_activity_day": "",
		"last_activity_type": "",
		"last_track_key": ""
	}


static func _days_between(date_a: String, date_b: String) -> int:
	if date_a.is_empty() or date_b.is_empty():
		return -1
	var unix_a: int = int(Time.get_unix_time_from_datetime_string(date_a))
	var unix_b: int = int(Time.get_unix_time_from_datetime_string(date_b))
	return int(float(absi(unix_b - unix_a)) / SECONDS_PER_DAY)


static func _is_valid_date(date_string: String) -> bool:
	if date_string.is_empty():
		return false
	var unix: int = int(Time.get_unix_time_from_datetime_string(date_string))
	return Time.get_date_string_from_unix_time(unix) == date_string


static func _resolver_fecha_actual(current_date: String) -> String:
	var clean_date: String = current_date.strip_edges()
	if not clean_date.is_empty():
		return clean_date
	return Time.get_date_string_from_system(false)


static func _esta_en_ventana_de_warning(current_hour: int) -> bool:
	return _resolver_hora_actual(current_hour) >= WARNING_START_HOUR_LOCAL


static func _resolver_hora_actual(current_hour: int) -> int:
	if current_hour >= 0:
		return clampi(current_hour, 0, 23)
	var now: Dictionary = Time.get_datetime_dict_from_system(false)
	return clampi(int(now.get("hour", 0)), 0, 23)
