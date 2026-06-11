class_name AuthSession
extends RefCounted

var _token: String = ""
var _username: String = ""
# Generación de sesión: se incrementa en cada login/logout/expiración.
# Los flujos async capturan el valor antes de un await y abortan si cambió
# al reanudar, para no aplicar datos de una sesión anterior sobre la actual.
var _epoch: int = 0


func esta_logueado() -> bool:
	return not _token.is_empty()


func obtener_token() -> String:
	return _token


func obtener_epoch() -> int:
	return _epoch


func establecer_sesion(token: String, username: String = "") -> void:
	_token = token
	_username = username
	_epoch += 1


func limpiar_sesion() -> void:
	_token = ""
	_username = ""
	_epoch += 1


func obtener_usuario() -> String:
	return _username
