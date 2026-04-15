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

	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("STREAK STATE SERVICE TEST FAILED: %s" % message)