class_name AuthSession
extends RefCounted

var _token: String = ""
var _username: String = ""


## Devuelve true si hay un token cargado en memoria.
func is_logged_in() -> bool:
	return not _token.is_empty()


## Devuelve el token JWT actual. Vacío si no hay sesión.
func get_token() -> String:
	return _token


## Establece la sesión en memoria.
## username es opcional; se usa solo para mostrar al jugador.
func set_session(token: String, username: String = "") -> void:
	_token = token
	_username = username


## Borra la sesión de memoria (logout o token expirado).
func clear_session() -> void:
	_token = ""
	_username = ""


## Devuelve el nombre de usuario de la sesión activa. Vacío si no hay sesión.
func get_username() -> String:
	return _username
