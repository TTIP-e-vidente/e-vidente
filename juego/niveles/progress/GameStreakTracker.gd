extends RefCounted

# GameStreakTracker.gd
# Calcula la racha solo cuando se registra una actividad real.
# Leer o abrir pantallas no debe incrementar ni recalcular dias.

const SECONDS_PER_DAY := 86400


# --- Estado estable ---------------------------------------------------------

static func leer(raw_state: Variant) -> Dictionary:
	if not raw_state is Dictionary:
		return _empty_streak_state()

	var stored: Dictionary = raw_state
	var last_day: String = _normalizar_dia_actividad(stored.get("last_activity_day", ""))
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
	var today: String = Time.get_date_string_from_system(true)
	var last_day: String = _normalizar_dia_actividad(streak_state.get("last_activity_day", ""))
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
	var last_day: String = _normalizar_dia_actividad(streak_state.get("last_activity_day", ""))
	if last_day.is_empty() and current_count > 0:
		return "inactive"
	if last_day == today:
		return "active"
	if not last_day.is_empty() and last_day > today:
		# El servidor puede guardar la fecha en UTC un día adelantada respecto al cliente.
		if _days_between(today, last_day) == 1:
			return "active"
	if _days_between(last_day, today) == 1:
		return "warning"
	return "inactive"


static func modelo_vista(
	streak_state: Dictionary,
	current_date: String = "",
	current_hour: int = -1
) -> Dictionary:
	var current_count: int = int(streak_state.get("current_count", 0))
	var best_count: int = int(streak_state.get("best_count", 0))
	var last_day: String = _normalizar_dia_actividad(streak_state.get("last_activity_day", ""))
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
		var today: String = Time.get_date_string_from_system(true)
		var already_played_today: bool = str(previous_state.get("last_activity_day", "")) == today
		var streak_updated_today: bool = str(updated_state.get("last_activity_day", "")) == today
		if already_played_today or not streak_updated_today:
			return {"should_show": false}

	var count: int = max(0, int(updated_state.get("current_count", 0)))
	var previous_count: int = max(0, int(previous_state.get("current_count", 0)))
	if count <= 0:
		return {"should_show": false}
	var best: int = max(count, int(updated_state.get("best_count", 0)))

	if count == 1 and previous_count > 1:
		return {
			"should_show": true,
			"feedback_key": "restarted",
			"title": "Tu racha se reinició",
			"message": "Tenías %d días seguidos. ¡Arrancá de nuevo!" % previous_count,
			"current_count": 1,
			"best_count": best,
			"previous_count": previous_count
		}

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


# --- Merge local / servidor -----------------------------------------------

static func fusionar_con_remoto(local: Dictionary, online: Dictionary) -> Dictionary:
	var local_read := leer(local)
	var online_read := leer(online)
	var best_count := maxi(
		int(local_read.get("best_count", 0)),
		int(online_read.get("best_count", 0))
	)

	if local_read.is_empty():
		if online_read.is_empty():
			return _empty_streak_state()
		var solo_online := online_read.duplicate(true)
		solo_online["best_count"] = best_count
		return leer(solo_online)

	if online_read.is_empty():
		var solo_local := local_read.duplicate(true)
		solo_local["best_count"] = best_count
		return leer(solo_local)

	var today := Time.get_date_string_from_system(true)
	var local_day := str(local_read.get("last_activity_day", ""))
	var online_day := str(online_read.get("last_activity_day", ""))

	# La sesión local de hoy manda: evita que un count remoto viejo pise last_activity_day.
	if local_day == today:
		var merged_hoy := local_read.duplicate(true)
		if online_day == today:
			merged_hoy["current_count"] = maxi(
				int(local_read.get("current_count", 0)),
				int(online_read.get("current_count", 0))
			)
		merged_hoy["best_count"] = best_count
		return leer(merged_hoy)

	if online_day == today:
		var merged_remoto_hoy := online_read.duplicate(true)
		merged_remoto_hoy["best_count"] = best_count
		return leer(merged_remoto_hoy)

	var local_count := int(local_read.get("current_count", 0))
	var online_count := int(online_read.get("current_count", 0))
	var local_alive := _racha_vigente_en_fecha(local_day, today)
	var online_alive := _racha_vigente_en_fecha(online_day, today)

	if not local_alive:
		local_count = 0
	if not online_alive:
		online_count = 0

	var ganador: Dictionary
	if local_count > online_count:
		ganador = local_read.duplicate(true)
	elif online_count > local_count:
		ganador = online_read.duplicate(true)
	elif local_day >= online_day:
		ganador = local_read.duplicate(true)
	else:
		ganador = online_read.duplicate(true)

	ganador["last_activity_day"] = _dia_mas_reciente(local_day, online_day)
	if not local_alive and not online_alive:
		ganador["current_count"] = 0

	ganador["best_count"] = best_count
	var merged := leer(ganador)
	# Salvaguarda: si la sesión local jugó hoy, no retroceder last_activity_day.
	if local_day == today and str(merged.get("last_activity_day", "")) != today:
		merged["last_activity_day"] = today
		merged["current_count"] = maxi(
			int(merged.get("current_count", 0)),
			int(local_read.get("current_count", 0))
		)
	return merged


# --- Helpers internos -------------------------------------------------------

static func _empty_streak_state() -> Dictionary:
	return {
		"current_count": 0,
		"best_count": 0,
		"last_activity_day": "",
		"last_activity_type": "",
		"last_track_key": ""
	}


static func _racha_vigente_en_fecha(last_day: String, today: String) -> bool:
	if last_day.is_empty() or today.is_empty():
		return false
	if last_day == today:
		return true
	return _days_between(last_day, today) == 1


static func _dia_mas_reciente(day_a: String, day_b: String) -> String:
	if day_a.is_empty():
		return day_b
	if day_b.is_empty():
		return day_a
	return day_a if day_a > day_b else day_b


static func _days_between(date_a: String, date_b: String) -> int:
	var norm_a := _normalizar_dia_actividad(date_a)
	var norm_b := _normalizar_dia_actividad(date_b)
	if norm_a.is_empty() or norm_b.is_empty():
		return -1
	var unix_a: int = int(Time.get_unix_time_from_datetime_string(norm_a))
	var unix_b: int = int(Time.get_unix_time_from_datetime_string(norm_b))
	return int(float(absi(unix_b - unix_a)) / SECONDS_PER_DAY)


static func _normalizar_dia_actividad(raw_value: Variant) -> String:
	var raw_text := str(raw_value).strip_edges()
	if raw_text.is_empty():
		return ""

	if "T" in raw_text:
		raw_text = raw_text.split("T", false, 1)[0].strip_edges()

	if _is_valid_date(raw_text):
		return raw_text

	var unix: int = int(Time.get_unix_time_from_datetime_string(str(raw_value).strip_edges()))
	if unix <= 0:
		return ""

	var normalized := Time.get_date_string_from_unix_time(unix)
	return normalized if _is_valid_date(normalized) else ""


static func _is_valid_date(date_string: String) -> bool:
	if date_string.is_empty():
		return false
	var unix: int = int(Time.get_unix_time_from_datetime_string(date_string))
	return Time.get_date_string_from_unix_time(unix) == date_string


static func _resolver_fecha_actual(current_date: String) -> String:
	var clean_date: String = current_date.strip_edges()
	if not clean_date.is_empty():
		return clean_date
	return Time.get_date_string_from_system(true)
