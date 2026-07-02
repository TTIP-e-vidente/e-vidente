class_name AuthSession
extends RefCounted

var _token: String = ""
var _username: String = ""
# Clave de cuenta local: username + sufijo de entorno ("agus" en Supabase,
# "agus@local" en Postgres local). Separa saves/cola de sync entre entornos
# para que el mismo username no mezcle datos.
var _clave_cuenta: String = ""
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


func establecer_sesion(token: String, username: String = "", clave_cuenta: String = "") -> void:
	_token = token
	_username = username
	_clave_cuenta = clave_cuenta.strip_edges() if not clave_cuenta.strip_edges().is_empty() else username
	_epoch += 1


func limpiar_sesion() -> void:
	_token = ""
	_username = ""
	_clave_cuenta = ""
	_epoch += 1


func obtener_usuario() -> String:
	return _username


func obtener_clave_cuenta() -> String:
	return _clave_cuenta if not _clave_cuenta.is_empty() else _username
