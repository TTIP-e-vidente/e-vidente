## BackendSessionStorage: sesión en user://
## Persistencia local de sesión.
## Guarda token/usuario en user://backend_session.json.
## No guarda password.
##
## Qué guarda:   token JWT, username, datos públicos del usuario, timestamp.
## Qué NO guarda: password ni ningún dato sensible adicional.
##
## Todos los métodos son static — no necesita instanciarse.
## No hace HTTP. No conoce gameplay. No toca SaveManager.

class_name BackendSessionStorage
extends RefCounted

const SESSION_PATH := "user://backend_session.json"


## Persiste la sesión en disco.
## token    : JWT de acceso recibido del backend.
## username : nombre de usuario para mostrar (sin valor sensible).
## user     : diccionario público devuelto por /auth/me (sin password).
static func save_session(
	token: String,
	username: String = "",
	user: Dictionary = {}
) -> void:
	var payload := {
		"token":    token,
		"username": username,
		"user":     user,
		"savedAt":  Time.get_datetime_string_from_system(false, true),
	}
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[BackendSessionStorage] No se pudo abrir %s para escritura." % SESSION_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Carga la sesión desde disco.
## Devuelve un Dictionary con los datos si el archivo existe y es JSON válido.
## Devuelve {} si el archivo no existe o el contenido está corrupto.
static func load_session() -> Dictionary:
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


## Borra el archivo de sesión si existe.
static func clear_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		var err := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SESSION_PATH)
		)
		if err != OK:
			# Fallback: sobreescribir con JSON vacío si el remove falla
			var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
			if file != null:
				file.store_string("{}")
				file.close()
