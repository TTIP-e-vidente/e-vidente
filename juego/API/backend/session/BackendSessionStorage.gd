class_name BackendSessionStorage
extends RefCounted

const SESSION_PATH := "user://backend_session.json"


static func guardar_sesion(
	token: String,
	username: String = "",
	user: Dictionary = {},
	entorno: String = ""
) -> void:
	var payload := {
		"token": token,
		"username": username,
		"user": user,
		# Espacio de datos del token ("supabase" | "local"): al restaurar,
		# una sesión de otro entorno se ignora para no mezclar datos.
		"entorno": entorno if not entorno.is_empty() else "supabase",
		"savedAt": Time.get_datetime_string_from_system(false, true),
	}
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[BackendSessionStorage] No se pudo abrir %s para escritura." % SESSION_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


static func cargar_sesion() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return {}
	var raw: String = file.get_as_text()
	file.close()
	if raw.is_empty():
		return {}
	var parsed = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		push_warning("[BackendSessionStorage] Sesión en disco corrupta — se ignorará.")
		return {}
	return parsed as Dictionary


static func borrar_sesion() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		var err := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SESSION_PATH)
		)
		if err != OK:
			var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
			if file != null:
				file.store_string("{}")
				file.close()
