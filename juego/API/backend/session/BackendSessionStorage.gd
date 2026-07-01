class_name BackendSessionStorage
extends RefCounted

const SESSION_PATH := "user://backend_session.json"


static func guardar_sesion(
	token: String,
	username: String = "",
	user: Dictionary = {}
) -> void:
	var payload := {
		"token": token,
		"username": username,
		"user": user,
		"savedAt": Time.get_datetime_string_from_system(false, true),
	}
	var path := _ruta_sesion()
	BackendStoragePaths.asegurar_directorio_padre(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[BackendSessionStorage] No se pudo abrir %s para escritura." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


static func cargar_sesion() -> Dictionary:
	var path := _ruta_sesion()
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
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
	var path := _ruta_sesion()
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(path)
		)
		if err != OK:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string("{}")
				file.close()


static func _ruta_sesion() -> String:
	return BackendStoragePaths.resolver(SESSION_PATH)
