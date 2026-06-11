extends GdUnitTestSuite
class_name TestRachaSync

const GameStreakTracker := preload("res://niveles/progress/GameStreakTracker.gd")


func test_merge_local_hoy_no_reinicia_racha_online_de_ayer() -> void:
	var today := Time.get_date_string_from_system(true)
	var yesterday := _dia_anterior(today)
	var local_today := {
		"current_count": 1,
		"best_count": 1,
		"last_activity_day": today,
	}
	var online_yesterday := {
		"current_count": 2,
		"best_count": 2,
		"last_activity_day": yesterday,
	}

	var merged: Dictionary = GameStreakTracker.fusionar_con_remoto(
		local_today,
		online_yesterday
	)

	assert_int(int(merged.get("current_count", 0))).is_equal(3)
	assert_int(int(merged.get("best_count", 0))).is_equal(3)
	assert_str(str(merged.get("last_activity_day", ""))).is_equal(today)


func test_merge_local_hoy_toma_mayor_racha_online_de_hoy() -> void:
	var today := Time.get_date_string_from_system(true)
	var local_today := {
		"current_count": 1,
		"best_count": 1,
		"last_activity_day": today,
	}
	var online_today := {
		"current_count": 2,
		"best_count": 2,
		"last_activity_day": today,
	}

	var merged: Dictionary = GameStreakTracker.fusionar_con_remoto(
		local_today,
		online_today
	)

	assert_int(int(merged.get("current_count", 0))).is_equal(2)
	assert_int(int(merged.get("best_count", 0))).is_equal(2)
	assert_str(str(merged.get("last_activity_day", ""))).is_equal(today)


func test_merge_online_de_hoy_no_pisa_racha_local_viva_de_ayer() -> void:
	# Bug reportado: agus tenía racha 3 (local, ayer) y el server decía 1 (hoy,
	# por datos corruptos); el merge devolvía 1. La continuidad local manda:
	# ayer 3 + actividad de hoy = 4.
	var today := Time.get_date_string_from_system(true)
	var yesterday := _dia_anterior(today)
	var local_ayer := {
		"current_count": 3,
		"best_count": 3,
		"last_activity_day": yesterday,
	}
	var online_hoy_corrupto := {
		"current_count": 1,
		"best_count": 1,
		"last_activity_day": today,
	}

	var merged: Dictionary = GameStreakTracker.fusionar_con_remoto(
		local_ayer,
		online_hoy_corrupto
	)

	assert_int(int(merged.get("current_count", 0))).is_equal(4)
	assert_int(int(merged.get("best_count", 0))).is_equal(4)
	assert_str(str(merged.get("last_activity_day", ""))).is_equal(today)


func test_merge_conserva_ultima_interaccion_mas_reciente() -> void:
	var today := Time.get_date_string_from_system(true)
	var local_state := {
		"current_count": 2,
		"best_count": 2,
		"last_activity_day": today,
		"last_activity_at": today + "T08:00:00Z",
	}
	var online_state := {
		"current_count": 2,
		"best_count": 2,
		"last_activity_day": today,
		"last_activity_at": today + "T12:30:00Z",
	}

	var merged: Dictionary = GameStreakTracker.fusionar_con_remoto(local_state, online_state)

	assert_str(str(merged.get("last_activity_at", ""))).is_equal(today + "T12:30:00Z")


func test_registrar_persiste_momento_de_ultima_interaccion() -> void:
	var updated: Dictionary = GameStreakTracker.registrar({}, "question_session_completed", {})

	assert_str(str(updated.get("last_activity_at", ""))).is_not_empty()
	# leer() debe preservar el campo al normalizar (round-trip de persistencia).
	var releido: Dictionary = GameStreakTracker.leer(updated)
	assert_str(str(releido.get("last_activity_at", ""))).is_equal(
		str(updated.get("last_activity_at", ""))
	)


func test_modelo_vista_racha_de_ayer_es_warning_por_vencerse() -> void:
	var today := Time.get_date_string_from_system(true)
	var streak := {
		"current_count": 3,
		"best_count": 5,
		"last_activity_day": _dia_anterior(today),
	}

	var vista: Dictionary = GameStreakTracker.modelo_vista(streak)

	assert_str(str(vista.get("status_key", ""))).is_equal("pending_today")
	assert_str(str(vista.get("streak_state", ""))).is_equal("warning")
	assert_int(int(vista.get("current_count", 0))).is_equal(3)


func test_modelo_vista_racha_vencida_queda_en_gris_con_cero() -> void:
	var today := Time.get_date_string_from_system(true)
	var hace_tres_dias := _dia_anterior(_dia_anterior(_dia_anterior(today)))
	var streak := {
		"current_count": 3,
		"best_count": 5,
		"last_activity_day": hace_tres_dias,
	}

	var vista: Dictionary = GameStreakTracker.modelo_vista(streak)

	assert_str(str(vista.get("status_key", ""))).is_equal("expired")
	assert_str(str(vista.get("streak_state", ""))).is_equal("inactive")
	assert_int(int(vista.get("current_count", -1))).is_equal(0)
	assert_int(int(vista.get("previous_count", 0))).is_equal(3)
	assert_int(int(vista.get("best_count", 0))).is_equal(5)


func test_modelo_vista_racha_de_hoy_es_activa() -> void:
	var streak := {
		"current_count": 4,
		"best_count": 4,
		"last_activity_day": Time.get_date_string_from_system(true),
	}

	var vista: Dictionary = GameStreakTracker.modelo_vista(streak)

	assert_str(str(vista.get("status_key", ""))).is_equal("active_today")
	assert_str(str(vista.get("streak_state", ""))).is_equal("active")
	assert_int(int(vista.get("current_count", 0))).is_equal(4)


func _dia_anterior(today: String) -> String:
	var unix_today := int(Time.get_unix_time_from_datetime_string(today))
	return Time.get_date_string_from_unix_time(unix_today - GameStreakTracker.SECONDS_PER_DAY)
