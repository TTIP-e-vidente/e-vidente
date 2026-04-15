extends SceneTree

const GameStreakStateServiceScript := preload(
	"res://niveles/progress/GameStreakStateService.gd"
)

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var streak_service = GameStreakStateServiceScript.new()

	var default_state: Dictionary = streak_service.normalize_state({})
	_assert(
		int(default_state.get("current_count", -1)) == 0,
		"La racha default deberia arrancar en cero"
	)
	_assert(
		int(default_state.get("best_count", -1)) == 0,
		"La mejor racha default deberia arrancar en cero"
	)

	var first_state: Dictionary = streak_service.record_activity(
		{},
		"level_completed",
		{
			"track_key": "celiaquia",
			"activity_day": "2026-04-14",
			"activity_at": "2026-04-14 09:15:00"
		}
	)
	_assert(
		int(first_state.get("current_count", 0)) == 1,
		"La primera actividad valida deberia iniciar la racha en 1"
	)
	_assert(
		int(first_state.get("best_count", 0)) == 1,
		"La primera actividad valida deberia fijar record en 1"
	)
	_assert(
		str(first_state.get("last_track_key", "")) == "celiaquia",
		"La racha deberia recordar el track de la ultima actividad"
	)

	var same_day_state: Dictionary = streak_service.record_activity(
		first_state,
		"question_session_completed",
		{
			"activity_day": "2026-04-14",
			"activity_at": "2026-04-14 20:10:00"
		}
	)
	_assert(
		int(same_day_state.get("current_count", 0)) == 1,
		"Una segunda actividad el mismo dia no deberia subir la racha"
	)
	_assert(
		str(same_day_state.get("last_activity_type", "")) == "question_session_completed",
		"La racha deberia guardar el ultimo tipo de actividad valido"
	)

	var next_day_state: Dictionary = streak_service.record_activity(
		same_day_state,
		"level_completed",
		{
			"track_key": "veganismo",
			"activity_day": "2026-04-15",
			"activity_at": "2026-04-15 08:00:00"
		}
	)
	_assert(
		int(next_day_state.get("current_count", 0)) == 2,
		"Una actividad al dia siguiente deberia subir la racha"
	)
	_assert(
		int(next_day_state.get("best_count", 0)) == 2,
		"La mejor racha deberia acompañar la racha actual"
	)

	var gap_state: Dictionary = streak_service.record_activity(
		next_day_state,
		"level_completed",
		{
			"track_key": "cetogenica",
			"activity_day": "2026-04-18",
			"activity_at": "2026-04-18 11:30:00"
		}
	)
	_assert(
		int(gap_state.get("current_count", 0)) == 1,
		"Un hueco de mas de un dia deberia reiniciar la racha actual"
	)
	_assert(
		int(gap_state.get("best_count", 0)) == 2,
		"Reiniciar la racha actual no deberia borrar la mejor marca"
	)

	var repaired_state: Dictionary = streak_service.normalize_state(
		{
			"current_count": 5,
			"best_count": 1,
			"last_activity_day": "",
			"last_activity_type": "broken"
		}
	)
	_assert(
		int(repaired_state.get("current_count", -1)) == 0,
		"Sin fecha valida no deberia sobrevivir una racha actual"
	)
	_assert(
		int(repaired_state.get("best_count", -1)) == 1,
		"La mejor racha historica no deberia perderse al normalizar"
	)

	var empty_summary := streak_service.format_summary_text({})
	_assert(
		empty_summary.contains("sin actividad valida"),
		"La UI deberia explicar cuando todavia no existe actividad valida"
	)

	var empty_view_model: Dictionary = streak_service.build_view_model({})
	_assert(
		str(empty_view_model.get("status_key", "")) == "inactive",
		"Sin actividad previa la UI deberia marcar la racha como inactiva"
	)
	_assert(
		not bool(empty_view_model.get("recorded_today", true)),
		"Sin actividad previa no deberia figurar progreso para hoy"
	)

	var pending_view_model: Dictionary = streak_service.build_view_model(
		{
			"current_count": 3,
			"best_count": 5,
			"last_activity_day": _day_offset_from_today(-1),
			"last_activity_at": "%s 10:00:00" % _day_offset_from_today(-1),
			"last_activity_type": "level_completed",
			"last_track_key": "veganismo"
		}
	)
	_assert(
		str(pending_view_model.get("status_key", "")) == "pending_today",
		"Si la ultima actividad fue ayer la UI deberia marcar la racha como pendiente hoy"
	)
	_assert(
		bool(pending_view_model.get("pending_today", false)),
		"El view model deberia exponer explicitamente cuando hoy falta sostener la racha"
	)

	var active_view_model: Dictionary = streak_service.build_view_model(
		streak_service.record_activity(
			{},
			"level_completed",
			{
				"track_key": "celiaquia",
				"activity_day": Time.get_date_string_from_system(false),
				"activity_at": "%s 08:00:00" % Time.get_date_string_from_system(false)
			}
		)
	)
	_assert(
		str(active_view_model.get("status_key", "")) == "active_today",
		"Una actividad valida hoy deberia marcar la racha como activa"
	)
	_assert(
		str(active_view_model.get("last_activity_type_label", "")) == "nivel completado",
		"El view model deberia resolver una etiqueta legible para el ultimo tipo de actividad"
	)

	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("STREAK STATE SERVICE TEST FAILED: %s" % message)


func _day_offset_from_today(offset_days: int) -> String:
	var today_unix: int = int(Time.get_unix_time_from_system())
	var target_unix: int = today_unix + (offset_days * 86400)
	return Time.get_date_string_from_unix_time(target_unix)
