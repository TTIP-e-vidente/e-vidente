extends RefCounted


func profile_name_for_form(profile: Dictionary, default_profile_name: String) -> String:
	var username := str(profile.get("username", ""))
	if username == default_profile_name:
		return ""
	return username


func age_for_form(profile: Dictionary) -> String:
	var age := int(profile.get("age", 0))
	if age <= 0:
		return ""
	return str(age)


func parse_age(value: String) -> Dictionary:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return {"ok": true, "value": 0}
	if not clean_value.is_valid_int():
		return {"ok": false, "message": "La edad debe ser un numero entero o quedar vacia."}
	var parsed_age := int(clean_value)
	if parsed_age < 0:
		return {"ok": false, "message": "La edad no puede ser negativa."}
	return {"ok": true, "value": parsed_age}


func build_preview(profile_name: String, email: String, age_text: String, default_profile_name: String) -> Dictionary:
	var clean_name := profile_name.strip_edges()
	return {
		"username": clean_name if not clean_name.is_empty() else default_profile_name,
		"email": "Mail: %s" % format_optional_preview_text(email),
		"age": format_preview_age(age_text)
	}


func format_optional_preview_text(value: String) -> String:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return "sin dato"
	return clean_value


func format_preview_age(value: String) -> String:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return "Edad: sin dato"
	if not clean_value.is_valid_int() or int(clean_value) < 0:
		return "Edad: revisar"
	return "Edad: %s" % clean_value


func format_save_reason(reason: String) -> String:
	match reason:
		"profile_updated":
			return "perfil actualizado"
		"manual_save":
			return "guardado manual"
		"progress_reset":
			return "progreso reiniciado"
		"level_completed":
			return "avance persistido"
		"progress_sync":
			return "sincronizacion de progreso"
		"load_repair":
			return "reparacion del save"
		_:
			return reason.replace("_", " ")


func build_summary_save_text(save_status: Dictionary) -> String:
	var last_reason := str(save_status.get("last_saved_reason", ""))
	if last_reason.is_empty():
		return "Ultimo guardado: todavia no hay escrituras registradas."
	return "Ultimo guardado: %s" % format_save_reason(last_reason)