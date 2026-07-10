class_name AuthErrorFormatter
extends RefCounted

static func mensaje_desde_check_conexion(check: Dictionary, fallback: String = "") -> String:
	var payload: Dictionary = {}
	if check.get("result") is Dictionary:
		payload = (check.get("result") as Dictionary).duplicate(true)
	else:
		payload = check.duplicate(true)
	if check.has("phase"):
		payload["phase"] = str(check.get("phase", "")).strip_edges()
	return _mensaje_auth_generico(payload, fallback)


static func resumen_conexion_ok(_check: Dictionary) -> String:
	return "Listo para jugar."


static func mensaje_auth(result: Dictionary, fallback: String = "") -> String:
	return _mensaje_auth_generico(result, fallback)


static func mensaje_verificacion(result: Dictionary, _fallback: String = "") -> String:
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
			var detail := str(data.get("detail", result.get("detail", ""))).strip_edges()
			if not detail.is_empty():
				if "unrecognised IP" in detail or "unauthorized" in detail.to_lower():
					return (
						"No se pudo enviar el mail: Brevo bloqueó tu IP. "
						+ "Agregala en Brevo → Security → Authorized IPs o desactivá la restricción."
					)
				return "No se pudo enviar el código: %s" % detail
			return "No se pudo enviar el código. Intentá de nuevo."
		"EMAIL_UNAVAILABLE":
			if BackendConfig.es_modo_supabase_edge():
				if bool(data.get("dev_code_in_logs", false)):
					return "Brevo no está configurado en Edge. Revisá npm run supabase:functions:secrets en BACKEND."
				return "El servicio de mail no está disponible en Supabase Edge."
			if bool(data.get("dev_code_in_logs", false)):
				return "Brevo no está configurado. El código aparece en la consola del backend."
			return "El servicio de mail no está disponible. Reiniciá el backend (npm run dev:restart)."
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
		"MAIL_OUT_OF_SYNC":
			return (
				"El mail del formulario no coincide con tu cuenta. "
				+ "Guardá el perfil e intentá de nuevo."
			)

	return ""


static func mensaje_perfil_sync(result: Dictionary, fallback: String = "") -> String:
	var code := str(result.get("code", "")).strip_edges()
	match code:
		"MAIL_OUT_OF_SYNC":
			return mensaje_verificacion(result, "Guardá el mail en tu perfil antes de pedir el código.")
		"MAIL_SYNC_SKIPPED", "MAIL_SYNC_MISMATCH":
			return str(result.get("error", "")).strip_edges() if not str(result.get("error", "")).is_empty() else (
				"No pudimos sincronizar el mail con el servidor. Revisá la conexión y volvé a guardar."
			)
		"MAIL_NOT_VERIFIED":
			return "Verificá tu mail antes de activar recordatorios."
		"MAIL_NOT_SYNCED":
			return "Guardá el perfil para sincronizar el mail antes de verificar."
		"INVALID_MAIL":
			var invalid_msg := str(result.get("error", "")).strip_edges()
			return invalid_msg if not invalid_msg.is_empty() else "El mail no tiene un formato válido."
		"DUPLICATE_MAIL":
			return "Ese mail ya está en uso por otra cuenta."
		"PROFILE_REFRESH_FAILED":
			return (
				"No pudimos leer tu perfil del servidor. "
				+ "Revisá la conexión e intentá de nuevo."
			)
	return mensaje_auth(result, fallback if not fallback.is_empty() else "No se pudo sincronizar el perfil.")


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
	if BackendConfig.es_modo_supabase_edge():
		if not BackendConfig.edge_listo_para_usar():
			return (
				"Falta configurar Supabase Edge en Godot.\n"
				+ BackendConfig.mensaje_sync_requerido()
			)
		if result_code == HTTPRequest.RESULT_TIMEOUT:
			return (
				"Supabase Edge tardó demasiado (%s).\n" % BackendConfig.obtener_api_base_url()
				+ "Verificá tu conexión o npm run integrate:status en BACKEND."
			)
		return BackendConfig.mensaje_sin_conexion_edge()

	var base_url := BackendConfig.obtener_base_url()
	if result_code == HTTPRequest.RESULT_CANT_CONNECT:
		if phase == "db":
			return (
				"El backend responde pero Supabase no.\n"
				+ "En BACKEND ejecutá: npm run dev:staging"
			)
		if base_url.contains(":3000"):
			return (
				"No hay servidor en %s (puerto viejo).\n" % base_url
				+ "En BACKEND: npm run sync:godot-config:staging && npm run dev:staging"
			)
		return (
			"No hay servidor en %s.\n" % base_url
		)
	if result_code == HTTPRequest.RESULT_TIMEOUT:
		var hint := "¿Está npm run dev:staging corriendo en BACKEND?"
		if base_url.contains(":3000"):
			hint = (
				"Puerto incorrecto (3000). En BACKEND:\n"
				+ "  npm run sync:godot-config:staging\n"
				+ "  npm run dev:staging"
			)
		return (
			"El servidor tardó demasiado (%s).\n" % base_url
			+ hint
		)
	if not server_error.is_empty():
		return server_error
	return (
		"No se pudo conectar al backend (%s).\n" % base_url
		+ "Levantá BACKEND con: npm run dev"
	)


static func _mensaje_por_codigo(code: String) -> String:
	match code:
		"INVALID_CREDENTIALS":
			return "Usuario o contraseña incorrectos."
		"DUPLICATE_USERNAME":
			return "Ese nombre de usuario ya existe. Elegí otro."
		"DUPLICATE_MAIL":
			return "Ese mail ya está registrado. Probá iniciar sesión."
		"MAIL_NOT_VERIFIED":
			return "Verificá tu mail antes de activar recordatorios."
		"MAIL_NOT_SYNCED":
			return "Guardá el perfil para sincronizar el mail antes de verificar."
		"MAIL_OUT_OF_SYNC":
			return "Guardá el mail en tu perfil antes de pedir el código."
		"INVALID_BODY":
			return "Datos inválidos. Revisá usuario, mail y contraseña (mín. 8 caracteres)."
		"UNEXPECTED_ERROR":
			if BackendConfig.es_modo_supabase_edge():
				return "Error interno en Supabase Edge. Revisá logs en el dashboard de Supabase."
			return (
				"Error interno del servidor.\n"
				+ "Revisá la consola de BACKEND (npm run dev)."
			)
		"NOT_SUPABASE":
			if BackendConfig.es_modo_supabase_edge():
				return "Supabase Edge no responde correctamente. Corré npm run integrate:status en BACKEND."
			return (
				"El backend no usa Supabase (Postgres local).\n"
				+ "En BACKEND ejecutá: npm run dev"
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
				if BackendConfig.es_modo_supabase_edge():
					return (
						"Error de Supabase Edge (HTTP %d).\n" % status
						+ "Revisá npm run integrate:status en BACKEND."
					)
				return (
					"Error del servidor (HTTP %d).\n" % status
					+ "Revisá la consola de BACKEND (npm run dev)."
				)
			return server_error
