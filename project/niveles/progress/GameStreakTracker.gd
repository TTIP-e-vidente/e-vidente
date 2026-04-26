extends RefCounted

const SECONDS_PER_DAY := 86400


static func read(raw_state: Variant) -> Dictionary:
	if not raw_state is Dictionary:
		return _empty_streak_state()

	var stored: Dictionary = raw_state
	var last_day: String = str(stored.get("last_activity_day", "")).strip_edges()
	var current_count: int = max(0, int(stored.get("current_count", 0)))
	var best_count: int = max(0, int(stored.get("best_count", 0)))

	# Si la fecha guardada no es válida, la racha está rota
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


## Registra una actividad hoy y devuelve el nuevo estado de racha.
static func record(
	current_streak: Dictionary,
	activity_type: String,
	metadata: Dictionary
) -> Dictionary:
	var today: String = Time.get_date_string_from_system(false)
	var last_day: String = str(current_streak.get("last_activity_day", ""))
	var old_count: int = int(current_streak.get("current_count", 0))

	# Calcular nueva racha
	var new_count: int = 1
	if last_day == today:
		# Ya jugó hoy → mantener la cuenta actual
		new_count = old_count
	elif _days_between(last_day, today) == 1:
		# Jugó ayer → extender la racha
		new_count = old_count + 1

	var clean_type: String = activity_type.strip_edges()
	return {
		"current_count": new_count,
		"best_count": max(int(current_streak.get("best_count", 0)), new_count),
		"last_activity_day": today,
		"last_activity_type": "activity" if clean_type.is_empty() else clean_type,
		"last_track_key": str(metadata.get("track_key", "")).strip_edges()
	}


## Genera datos para mostrar en la UI del perfil / overlay.
static func view_model(streak_state: Dictionary) -> Dictionary:
	var current_count: int = int(streak_state.get("current_count", 0))
	var best_count: int = int(streak_state.get("best_count", 0))
	var last_day: String = str(streak_state.get("last_activity_day", ""))
	var today: String = Time.get_date_string_from_system(false)

	if current_count <= 0:
		return {
			"current_count": 0,
			"best_count": best_count,
			"status_key": "inactive",
			"status_title": "Sin racha activa",
			"status_detail": "Completa una actividad para iniciar la racha."
		}

	if last_day == today:
		return {
			"current_count": current_count,
			"best_count": best_count,
			"status_key": "active_today",
			"status_title": "Racha activa",
			"status_detail": "Hoy ya registraste una actividad."
		}

	return {
		"current_count": current_count,
		"best_count": best_count,
		"status_key": "pending_today",
		"status_title": "Racha pendiente hoy",
		"status_detail": "Tu racha sigue viva, pero todavia falta sostenerla hoy."
	}


static func build_feedback(
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

	var count: int = max(1, int(updated_state.get("current_count", 1)))
	var best: int = max(count, int(updated_state.get("best_count", 0)))

	if count <= 1:
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


# --- Helpers internos ---

static func _empty_streak_state() -> Dictionary:
	return {
		"current_count": 0,
		"best_count": 0,
		"last_activity_day": "",
		"last_activity_type": "",
		"last_track_key": ""
	}


## Devuelve cuántos días hay entre dos fechas "YYYY-MM-DD". Retorna -1 si alguna es inválida.
static func _days_between(date_a: String, date_b: String) -> int:
	if date_a.is_empty() or date_b.is_empty():
		return -1
	var unix_a: int = int(Time.get_unix_time_from_datetime_string(date_a))
	var unix_b: int = int(Time.get_unix_time_from_datetime_string(date_b))
	return int(float(absi(unix_b - unix_a)) / SECONDS_PER_DAY)


## Verifica que una fecha "YYYY-MM-DD" sea un formato válido.
static func _is_valid_date(date_string: String) -> bool:
	if date_string.is_empty():
		return false
	var unix: int = int(Time.get_unix_time_from_datetime_string(date_string))
	return Time.get_date_string_from_unix_time(unix) == date_string
