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
		"last_activity_at": str(stored.get("last_activity_at", "")).strip_edges(),
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
	var last_day: String = _dia_local_de_actividad(streak_state)
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
		# Momento exacto (UTC) de la última actividad que sostuvo la racha.
		"last_activity_at": Time.get_datetime_string_from_system(true) + "Z",
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

	var today: String = _resolver_fecha_local(current_date)
	var last_day: String = _dia_local_de_actividad(streak_state)
	if last_day.is_empty() and current_count > 0:
		return "inactive"
	if last_day == today:
		return "active"
	if _days_between(last_day, today) == 1:
		var hour := _resolver_hora_local(current_hour)
		if hour < 18:
			return "inactive"
		if hour >= 22:
			return "critical"
		return "warning"
	return "inactive"


static func modelo_vista(
	streak_state: Dictionary,
	current_date: String = "",
	current_hour: int = -1
) -> Dictionary:
	var current_count: int = int(streak_state.get("current_count", 0))
	var best_count: int = int(streak_state.get("best_count", 0))
	var last_day: String = _dia_local_de_actividad(streak_state)
	var today: String = _resolver_fecha_local(current_date)
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

	if _racha_vigente_en_fecha(last_day, today):
		# Jugó ayer: la racha sigue viva pero vence hoy → advertencia (roja).
		return {
			"current_count": current_count,
			"best_count": best_count,
			"status_key": "pending_today",
			"status_title": "Racha pendiente hoy",
			"status_detail": "Tu racha sigue viva, pero todavia falta sostenerla hoy.",
			"streak_state": visual_state
		}

	# La racha venció: más de un día sin actividad. Mostrarla en gris con
	# count 0; el valor anterior queda disponible para mensajes de UI.
	return {
		"current_count": 0,
		"previous_count": current_count,
		"best_count": best_count,
		"status_key": "expired",
		"status_title": "Racha cortada",
		"status_detail": (
			"Tu racha de %d %s se corto. Completa una actividad para empezar de nuevo."
			% [current_count, "dia" if current_count == 1 else "dias"]
		),
		"streak_state": "inactive"
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
		var already_played_today: bool = _dia_local_de_actividad(previous_state) == today
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


# --- Pérdida de racha -------------------------------------------------------

static func aplicar_vencimiento_si_corresponde(
	streak_state: Dictionary,
	streak_meta: Dictionary = {}
) -> Dictionary:
	var read_state := leer(streak_state)
	var vista := modelo_vista(read_state)
	if str(vista.get("status_key", "")) != "expired":
		return {
			"applied": false,
			"should_show": false,
			"updated_state": read_state,
		}

	var current_count: int = int(read_state.get("current_count", 0))
	var last_day: String = _dia_local_de_actividad(read_state)
	var already_notified: bool = (
		str(streak_meta.get("last_loss_notified_for_day", "")).strip_edges() == last_day
	)

	if current_count <= 0:
		return {
			"applied": false,
			"should_show": false,
			"updated_state": read_state,
		}

	var previous_count: int = current_count
	var updated := read_state.duplicate(true)
	updated["current_count"] = 0
	updated["best_count"] = maxi(int(updated.get("best_count", 0)), previous_count)
	updated = leer(updated)

	if already_notified:
		return {
			"applied": true,
			"should_show": false,
			"updated_state": updated,
			"notify_day": last_day,
		}

	return {
		"applied": true,
		"should_show": true,
		"updated_state": updated,
		"feedback": construir_feedback_perdida(previous_count, updated),
		"notify_day": last_day,
	}


static func construir_feedback_perdida(
	previous_count: int,
	updated_state: Dictionary = {}
) -> Dictionary:
	var best_count: int = maxi(
		previous_count,
		int(updated_state.get("best_count", 0))
	)
	return {
		"should_show": true,
		"feedback_key": "lost",
		"title": "Tu racha se cortó",
		"message": (
			"Tenías %d %s seguidos. ¡Arrancá de nuevo!"
			% [previous_count, "día" if previous_count == 1 else "días"]
		),
		"current_count": 0,
		"previous_count": previous_count,
		"best_count": best_count,
	}


# --- Merge local / servidor -----------------------------------------------

static func fusionar_con_remoto(local: Dictionary, online: Dictionary) -> Dictionary:
	var local_read := leer(local)
	var online_read := leer(online)
	var best_count := maxi(
		int(local_read.get("best_count", 0)),
		int(online_read.get("best_count", 0))
	)

	# leer() siempre devuelve un dict con claves: la ausencia de racha se
	# detecta por su contenido, no con is_empty().
	if _es_estado_sin_racha(local_read):
		if _es_estado_sin_racha(online_read):
			var vacio := _empty_streak_state()
			vacio["best_count"] = best_count
			return vacio
		var solo_online := online_read.duplicate(true)
		solo_online["best_count"] = best_count
		return leer(solo_online)

	if _es_estado_sin_racha(online_read):
		var solo_local := local_read.duplicate(true)
		solo_local["best_count"] = best_count
		return leer(solo_local)

	var today := Time.get_date_string_from_system(false)
	var local_day := _dia_local_de_actividad(local_read)
	var online_day := _dia_local_de_actividad(online_read)

	# La sesión local de hoy manda: evita que un count remoto viejo pise last_activity_day.
	if local_day == today:
		var merged_hoy := local_read.duplicate(true)
		if online_day == today:
			merged_hoy["current_count"] = maxi(
				int(local_read.get("current_count", 0)),
				int(online_read.get("current_count", 0))
			)
		elif _days_between(online_day, today) == 1:
			merged_hoy["current_count"] = maxi(
				int(local_read.get("current_count", 0)),
				int(online_read.get("current_count", 0)) + 1
			)
		merged_hoy["best_count"] = best_count
		merged_hoy["best_count"] = maxi(
			int(merged_hoy.get("best_count", 0)),
			int(merged_hoy.get("current_count", 0))
		)
		merged_hoy["last_activity_at"] = _interaccion_mas_reciente(local_read, online_read)
		return leer(merged_hoy)

	if online_day == today:
		var merged_remoto_hoy := online_read.duplicate(true)
		# Espejo del caso local-hoy: si lo local venía vivo de ayer con un count
		# mayor, el server pudo haber reiniciado mal su racha (sync tardío,
		# datos viejos); la actividad de hoy continúa la racha local.
		if _days_between(local_day, today) == 1:
			merged_remoto_hoy["current_count"] = maxi(
				int(online_read.get("current_count", 0)),
				int(local_read.get("current_count", 0)) + 1
			)
		merged_remoto_hoy["best_count"] = maxi(
			best_count,
			int(merged_remoto_hoy.get("current_count", 0))
		)
		merged_remoto_hoy["last_activity_at"] = _interaccion_mas_reciente(local_read, online_read)
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
	# No poner current_count en 0 acá: evaluar_perdida_racha_pendiente() necesita
	# el valor previo para mostrar el overlay una sola vez al iniciar sesión.

	ganador["best_count"] = best_count
	ganador["last_activity_at"] = _interaccion_mas_reciente(local_read, online_read)
	var merged := leer(ganador)
	# Salvaguarda: si la sesión local jugó hoy, no retroceder last_activity_day.
	if local_day == today and str(merged.get("last_activity_day", "")) != today:
		merged["last_activity_day"] = today
		merged["current_count"] = maxi(
			int(merged.get("current_count", 0)),
			int(local_read.get("current_count", 0))
		)
	return merged


## Devuelve el timestamp de última actividad más reciente entre ambos estados.
static func _interaccion_mas_reciente(local_read: Dictionary, online_read: Dictionary) -> String:
	var local_at := str(local_read.get("last_activity_at", "")).strip_edges()
	var online_at := str(online_read.get("last_activity_at", "")).strip_edges()
	if local_at.is_empty():
		return online_at
	if online_at.is_empty():
		return local_at
	return local_at if local_at >= online_at else online_at


# --- Helpers internos -------------------------------------------------------

static func _empty_streak_state() -> Dictionary:
	return {
		"current_count": 0,
		"best_count": 0,
		"last_activity_day": "",
		"last_activity_at": "",
		"last_activity_type": "",
		"last_track_key": ""
	}


static func _es_estado_sin_racha(state: Dictionary) -> bool:
	return (
		int(state.get("current_count", 0)) <= 0
		and str(state.get("last_activity_day", "")).is_empty()
	)


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


static func _resolver_fecha_local(current_date: String = "") -> String:
	var clean_date: String = current_date.strip_edges()
	if not clean_date.is_empty():
		return clean_date
	return Time.get_date_string_from_system(false)


static func _resolver_hora_local(current_hour: int = -1) -> int:
	if current_hour >= 0 and current_hour <= 23:
		return current_hour
	return int(Time.get_datetime_dict_from_system(false).get("hour", 0))


static func _dia_local_de_actividad(streak_state: Dictionary) -> String:
	var last_at := str(streak_state.get("last_activity_at", "")).strip_edges()
	if not last_at.is_empty():
		var unix_at := int(Time.get_unix_time_from_datetime_string(last_at))
		if unix_at > 0:
			var local_day := _fecha_local_desde_unix(unix_at)
			if _is_valid_date(local_day):
				return local_day

	return _normalizar_dia_actividad(streak_state.get("last_activity_day", ""))


## El signo de Time.get_time_zone_from_system().bias es inconsistente entre
## plataformas (invertido en Windows respecto a Android/Linux), así que no se
## usa: el offset local-UTC se calcula comparando el reloj local con el UTC.
static func _offset_local_menos_utc_segundos() -> int:
	var utc_unix: float = Time.get_unix_time_from_system()
	var local_dict: Dictionary = Time.get_datetime_dict_from_system(false)
	var local_unix_naive: float = Time.get_unix_time_from_datetime_dict(local_dict)
	return int(round(local_unix_naive - utc_unix))


static func _fecha_local_desde_unix(unix_time: int) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(
		unix_time + _offset_local_menos_utc_segundos()
	)
	return "%04d-%02d-%02d" % [int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0))]
