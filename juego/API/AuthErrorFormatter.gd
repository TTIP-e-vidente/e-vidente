class_name AuthErrorFormatter
extends RefCounted

static func mensaje_auth(result: Dictionary, fallback: String = "") -> String:
	return _mensaje_auth_generico(result, fallback)


static func mensaje_verificacion(result: Dictionary, fallback: String = "") -> String:
	var code := str(result.get("code", "")).strip_edges()
	var data: Dictionary = {}
	var raw_data: Variant = result.get("data", {})
	if raw_data is Dictionary:
		data = raw_data as Dictionary

	if code.is_empty():
		code = str(data.get("code", "")).strip_edges()

	match code:
		"RATE_LIMITED":
			var cooldown := int(data.get("cooldown_seconds", result.get("cooldown_seconds", 0)))
			if cooldown > 0:
				return "Esperá %d segundos antes de pedir otro código." % cooldown
			return "Esperá un momento antes de pedir otro código."
		"SEND_FAILED":
			return "No se pudo enviar el código. Intentá de nuevo en unos minutos."
		"EMAIL_UNAVAILABLE":
			return "El servicio de mail no está disponible. Contactá al equipo si persiste."
		"INVALID_CODE":
			var remaining := int(data.get("attempts_remaining", -1))
			if remaining >= 0:
				if remaining == 1:
					return "Código incorrecto. Te queda 1 intento."
				if remaining > 1:
					return "Código incorrecto. Te quedan %d intentos." % remaining
			return "Código incorrecto. Verificá e intentá de nuevo."
		"TOO_MANY_ATTEMPTS":
			return "Demasiados intentos incorrectos. Solicitá un código nuevo."
		"CODE_EXPIRED":
			return "El código expiró. Solicitá uno nuevo."
		"NO_PENDING_CODE":
			return "No hay código pendiente. Pedí uno nuevo primero."

	if not fallback.is_empty():
		return fallback
	return ""


static func cooldown_verificacion(result: Dictionary, fallback: int = 120) -> int:
	var data: Dictionary = {}
	var raw_data: Variant = result.get("data", {})
	if raw_data is Dictionary:
		data = raw_data as Dictionary
	for key in ["cooldown_seconds", "cooldownSeconds"]:
		var value := int(data.get(key, 0))
		if value > 0:
			return value
		value = int(result.get(key, 0))
		if value > 0:
			return value
	return fallback


static func _mensaje_auth_generico(result: Dictionary, fallback: String = "") -> String:
	var status := int(result.get("status", 0))
	var code := str(result.get("code", "")).strip_edges()
	var server_error := str(result.get("error", "")).strip_edges()
	var result_code := int(result.get("result_code", HTTPRequest.RESULT_SUCCESS))
	var phase := str(result.get("phase", "")).strip_edges()

	if status == 0:
		return _mensaje_sin_conexion(result_code, server_error, phase)

	if not code.is_empty():
		var por_codigo := _mensaje_por_codigo(code)
		if not por_codigo.is_empty():
			return por_codigo

	if not server_error.is_empty():
		var por_texto := _mensaje_por_texto_servidor(server_error, status)
		if not por_texto.is_empty():
			return por_texto

	if not fallback.is_empty():
		return fallback
	return "No se pudo completar la operación (HTTP %d)." % status

static func _mensaje_sin_conexion(
		result_code: int, server_error: String, phase: String) -> String:
	if result_code == HTTPRequest.RESULT_CANT_CONNECT:
		if phase == "db":
			return (
				"El backend responde pero Postgres no.\n"
				+ "En BACKEND ejecutá: docker compose up -d"
			)
		return (
			"No hay servidor en localhost:3000.\n"
			+ "1) cd BACKEND\n"
			+ "2) docker compose up -d\n"
			+ "3) npm run dev"
		)
	if result_code == HTTPRequest.RESULT_TIMEOUT:
		return "El servidor tardó demasiado. ¿Está npm run dev corriendo?"
	if not server_error.is_empty():
		return server_error
	return (
		"No se pudo conectar al backend.\n"
		+ "Levantá BACKEND con docker compose up -d && npm run dev"
	)


static func _mensaje_por_codigo(code: String) -> String:
	match code:
		"INVALID_CREDENTIALS":
			var msg := "Usuario o contraseña incorrectos."
			if OS.is_debug_build():
				msg += "\nDev: usuario agus, contraseña 123."
			return msg
		"DUPLICATE_USERNAME":
			return "Ese nombre de usuario ya existe. Elegí otro."
		"DUPLICATE_MAIL":
			return "Ese mail ya está registrado. Probá iniciar sesión."
		"INVALID_BODY":
			return "Datos inválidos. Revisá usuario, mail y contraseña (mín. 8 caracteres)."
		"UNEXPECTED_ERROR":
			return (
				"Error interno del servidor.\n"
				+ "Verificá Postgres: cd BACKEND && docker compose up -d"
			)
		_:
			return ""


static func _mensaje_por_texto_servidor(server_error: String, status: int) -> String:
	match server_error:
		"Invalid credentials":
			return _mensaje_por_codigo("INVALID_CREDENTIALS")
		"Unexpected error":
			return _mensaje_por_codigo("UNEXPECTED_ERROR")
		"username already exists":
			return _mensaje_por_codigo("DUPLICATE_USERNAME")
		"mail already exists":
			return _mensaje_por_codigo("DUPLICATE_MAIL")
		_:
			if status >= 500:
				return (
					"Error del servidor (HTTP %d).\n" % status
					+ "Revisá la consola de BACKEND y que Postgres esté activo."
				)
			return server_error
