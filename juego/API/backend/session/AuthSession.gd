class_name AuthSession
extends RefCounted

var _token: String = ""
var _username: String = ""


func esta_logueado() -> bool:
	return not _token.is_empty()


func obtener_token() -> String:
	return _token


func establecer_sesion(token: String, username: String = "") -> void:
	_token = token
	_username = username


func limpiar_sesion() -> void:
	_token = ""
	_username = ""


func obtener_usuario() -> String:
	return _username
