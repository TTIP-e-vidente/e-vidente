extends RefCounted


func format_save_status(status: Dictionary) -> String:
	var state := str(status.get("state", "idle"))
	var last_saved_at := str(status.get("last_saved_at", "sin datos"))
	var reason := format_save_reason(str(status.get("last_saved_reason", "")))
	var recovered_from := str(status.get("recovered_from", ""))
	var error_message := str(status.get("last_error", ""))

	match state:
		"error":
			return "No se pudo guardar.\n%s" % ("Reintenta de nuevo." if error_message.is_empty() else error_message)
		"recovered":
			return "Se recupero una copia desde %s\nUltimo guardado: %s" % [format_save_source(recovered_from), last_saved_at]
		"dirty":
			return "Hay cambios sin guardar\nPresiona Guardar para conservarlos"
		"saved":
			return "Ultimo guardado: %s\n%s" % [last_saved_at, reason]
		_:
			if last_saved_at == "sin datos" or last_saved_at.is_empty():
				return "Todavia no hay guardado local\nUsa Guardar cuando quieras conservar este avance"
			return "Ultimo guardado: %s\nListo para continuar" % last_saved_at


func format_save_reason(reason: String) -> String:
	match reason:
		"profile_updated":
			return "perfil actualizado"
		"new_game":
			return "nueva partida"
		"progress_sync":
			return "sincronizacion de progreso"
		"level_completed":
			return "nivel completado"
		"manual_save":
			return "guardado manual"
		"progress_reset":
			return "progreso reiniciado"
		"load_repair":
			return "reparacion al cargar"
		"legacy_migration":
			return "migracion legacy"
		_:
			return "guardado local"


func format_save_source(source: String) -> String:
	match source:
		"primary":
			return "tu guardado principal"
		"temp":
			return "un guardado temporal"
		"backup":
			return "una copia de respaldo"
		_:
			return "un estado nuevo"


func format_optional_text(value: String) -> String:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return "sin dato"
	return clean_value


func format_optional_number(value: int) -> String:
	if value <= 0:
		return "sin dato"
	return str(value)


func format_resume_hint_label(can_resume: bool, resume_hint: String) -> String:
	if can_resume:
		return "Retoma en %s\nSegui desde ese punto cuando quieras." % resume_hint
	return "Todavia no hay un punto guardado\nCuando avances en una partida aparecera aca"


func build_toggle_tooltip(save_status: Dictionary) -> String:
	var tooltip_lines := ["Abrir guardado local"]
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	if not last_saved_at.is_empty():
		tooltip_lines.append("Ultimo guardado: %s" % last_saved_at)
	return "\n".join(tooltip_lines)