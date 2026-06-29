class_name BackendApiClient
extends Node

# 8s: GET /player/me/progress corre una transacción con varias queries; con 3s
# expiraba en frío y el login quedaba sin datos online hasta el próximo intento.
const HTTP_TIMEOUT := 8.0
const AVATAR_UPLOAD_TIMEOUT := 30.0

var base_url: String = ""
var _supabase: SupabaseVerifyClient = null
var _edge: SupabaseEdgeClient = null


func _init() -> void:
	base_url = BackendConfig.obtener_base_url()
var _pool: Array[HTTPRequest] = []


func _adquirir_http() -> HTTPRequest:
	if not _pool.is_empty():
		return _pool.pop_back()
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	add_child(http)
	return http


func _liberar_http(http: HTTPRequest) -> void:
	_pool.push_back(http)


func _obtener_supabase() -> SupabaseVerifyClient:
	if _supabase == null:
		_supabase = SupabaseVerifyClient.new()
		add_child(_supabase)
	return _supabase


func _obtener_edge() -> SupabaseEdgeClient:
	if _edge == null:
		_edge = SupabaseEdgeClient.new()
		add_child(_edge)
	return _edge


func verificar_salud_api() -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		var salud := await _obtener_edge().enviar_get("auth-health", "")
		if not salud.get("ok", false):
			return salud
		var data: Dictionary = salud.get("data", {})
		if str(data.get("status", "")) != "ok":
			return {
				"ok": false,
				"status": salud.get("status", 503),
				"error": "API Edge no disponible",
				"data": data,
			}
		return {"ok": true, "status": 200, "data": {"status": "ok"}}
	return await _obtener_json("/health", "")


func verificar_salud_db() -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("auth-health", "")
	return await _obtener_json("/health/db", "")


func verificar_salud_email() -> Dictionary:
	if BackendConfig.email_via_supabase():
		return await _obtener_supabase().verificar_salud_email()
	return await _obtener_json("/health/email", "")


func iniciar_sesion(usuario_o_mail: String, clave: String) -> Dictionary:
	var body := JSON.stringify({
		"usernameOrMail": usuario_o_mail,
		"password": clave,
	})
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_post("auth-login", "", body)
	return await _enviar_post("/auth/login", "", body)


func registrar_cuenta(
	usuario: String,
	nombre: String,
	mail: String,
	clave: String,
	fecha_nacimiento: Variant = null,
	acepta_notificaciones_mail: bool = true,
	solicitar_verificacion_mail: bool = false
) -> Dictionary:
	var payload := {
		"username": usuario,
		"name": nombre,
		"mail": mail,
		"password": clave,
		"accept_email_notifications": acepta_notificaciones_mail,
		"request_email_verification": solicitar_verificacion_mail,
	}
	if fecha_nacimiento != null:
		var birth_date := str(fecha_nacimiento).strip_edges()
		if not birth_date.is_empty():
			payload["birth_date"] = birth_date
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_post("auth-register", "", JSON.stringify(payload))
	return await _enviar_post("/auth/register", "", JSON.stringify(payload))


func obtener_mi_usuario(token: String) -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("auth-me", token)
	return await _obtener_json("/auth/me", token)


func actualizar_perfil(token: String, payload: Dictionary) -> Dictionary:
	var body := JSON.stringify(payload)
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_patch("player-me", token, body)
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_PATCH, "/player/me", headers, body)


func guardar_progreso(token: String, resumen_partida: Dictionary) -> Dictionary:
	var body := JSON.stringify(resumen_partida)
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_post("player-progress-save", token, body)
	return await _enviar_post("/player/me/progress", token, body)


func guardar_progreso_batch(token: String, items: Array) -> Dictionary:
	var body := JSON.stringify({"items": items})
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_post("player-progress-batch", token, body)
	return await _enviar_post("/player/me/progress/batch", token, body)


func obtener_progreso(token: String) -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("player-progress-get", token)
	return await _obtener_json("/player/me/progress", token)


func reiniciar_progreso(token: String, restriction: String = "CELIAQUIA") -> Dictionary:
	var body := JSON.stringify({"restriction": restriction})
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_post("player-progress-reset", token, body)
	return await _enviar_post("/player/me/progress/reset", token, body)


func obtener_leaderboard(
	token: String,
	scope: String = "global_xp",
	limit: int = 50,
	offset: int = 0,
	include_self: bool = false
) -> Dictionary:
	var qs := "scope=%s&limit=%d&offset=%d" % [scope.uri_encode(), limit, offset]
	if include_self and not token.is_empty():
		qs += "&include_self=true"
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("leaderboard-list", token, qs)
	var endpoint := "/leaderboard?" + qs
	return await _obtener_json(endpoint, token)


func obtener_mi_posicion_leaderboard(token: String) -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("leaderboard-me", token)
	return await _obtener_json("/leaderboard/me", token)


# Obtiene el contexto competitivo del jugador (puesto actual, siguiente rival, EXP faltante).
# Endpoint: GET /leaderboard/me/summary
func obtener_resumen_ranking(token: String, scope: String = "global_xp") -> Dictionary:
	var qs := "scope=%s" % scope.strip_edges().uri_encode()
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("leaderboard-me-summary", token, qs)
	return await _obtener_json("/leaderboard/me/summary?" + qs, token)


func obtener_meta_leaderboard() -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("leaderboard-meta", "")
	return await _obtener_json("/leaderboard/meta", "")


func subir_avatar(token: String, data: String, mime_type: String) -> Dictionary:
	var body := JSON.stringify({"data": data, "mimeType": mime_type})
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_post_con_timeout(
			"avatar-upload", token, body, AVATAR_UPLOAD_TIMEOUT
		)
	var headers := _armar_headers(token)
	return await _enviar_peticion_con_timeout(
		HTTPClient.METHOD_POST, "/player/me/avatar", headers, body, AVATAR_UPLOAD_TIMEOUT
	)


func descargar_avatar(token: String) -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("avatar-get", token)
	return await _obtener_json("/player/me/avatar", token)


func descargar_avatar_publico(user_id: String) -> Dictionary:
	var clean_id := user_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "error": "userId vacío"}
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("avatar-public", "", "userId=" + clean_id.uri_encode())
	return await _obtener_json("/player/users/%s/avatar" % clean_id.uri_encode(), "")


func eliminar_avatar(token: String) -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_delete("avatar-delete", token)
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_DELETE, "/player/me/avatar", headers, "")


func solicitar_verificacion_email(token: String, mail_esperado: String = "") -> Dictionary:
	if BackendConfig.email_via_supabase():
		return await _obtener_supabase().solicitar_verificacion_email(token, mail_esperado)
	var body := {}
	var mail := mail_esperado.strip_edges()
	if not mail.is_empty():
		body["mail"] = mail
	return await _enviar_post("/player/verify-email/request", token, JSON.stringify(body))


func confirmar_verificacion_email(token: String, codigo: String) -> Dictionary:
	if BackendConfig.email_via_supabase():
		return await _obtener_supabase().confirmar_verificacion_email(token, codigo)
	var body := JSON.stringify({"code": codigo})
	return await _enviar_post("/player/verify-email/confirm", token, body)


func obtener_estado_email(token: String) -> Dictionary:
	if BackendConfig.es_modo_supabase_edge():
		return await _obtener_edge().enviar_get("player-email-status", token)
	return await _obtener_json("/player/me/email-status", token)


func _enviar_post(endpoint: String, token: String, body: String) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_POST, endpoint, headers, body)


func _obtener_json(endpoint: String, token: String) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_GET, endpoint, headers, "")


func _armar_headers(token: String) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	return headers


func _enviar_peticion(
	method: HTTPClient.Method,
	endpoint: String,
	headers: PackedStringArray,
	body: String
) -> Dictionary:
	var http := _adquirir_http()

	var start_error := http.request(base_url + endpoint, headers, method, body)
	if start_error != OK:
		_liberar_http(http)
		return {
			"ok": false,
			"status": 0,
			"error": "HTTPRequest no pudo iniciarse (error %d)" % start_error,
		}

	var result: Array = await http.request_completed
	_liberar_http(http)
	return _parsear_respuesta(method, endpoint, result)


# Para requests con payload grande (ej: avatar). Usa un nodo dedicado, no el pool.
func _enviar_peticion_con_timeout(
	method: HTTPClient.Method,
	endpoint: String,
	headers: PackedStringArray,
	body: String,
	timeout: float
) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)

	var start_error := http.request(base_url + endpoint, headers, method, body)
	if start_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"status": 0,
			"error": "HTTPRequest no pudo iniciarse (error %d)" % start_error,
		}

	var result: Array = await http.request_completed
	http.queue_free()
	return _parsear_respuesta(method, endpoint, result)


func _parsear_respuesta(
	method: HTTPClient.Method,
	endpoint: String,
	result: Array
) -> Dictionary:
	var result_code: int = result[0]
	var response_code: int = result[1]
	var body_bytes: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status": 0,
			"result_code": result_code,
			"error": _mensaje_error_conexion(result_code),
		}

	var body_text := body_bytes.get_string_from_utf8()
	var json := JSON.new()
	var parse_error := json.parse(body_text)

	if parse_error != OK:
		return {
			"ok": false,
			"status": response_code,
			"error": "JSON inválido en respuesta",
			"raw": body_text,
		}

	var is_ok := response_code >= 200 and response_code < 300
	var payload: Variant = json.data
	var error_message := ""
	var error_code := ""
	if payload is Dictionary:
		if not is_ok:
			error_message = str(payload.get("error", "")).strip_edges()
			error_code = str(payload.get("code", "")).strip_edges()
	if not is_ok:
		print(
			"[BackendApiClient] %s %s -> HTTP %d: %s"
			% [_nombre_metodo_http(method), endpoint, response_code, body_text]
		)
	return {
		"ok": is_ok,
		"status": response_code,
		"data": payload,
		"error": error_message,
		"code": error_code,
		"result_code": result_code,
	}


func _mensaje_error_conexion(result_code: int) -> String:
	match result_code:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "No se pudo conectar al servidor"
		HTTPRequest.RESULT_TIMEOUT:
			return "Tiempo de espera agotado"
		_:
			return "Petición fallida (HTTPRequest result_code %d)" % result_code


func _nombre_metodo_http(method: HTTPClient.Method) -> String:
	match method:
		HTTPClient.METHOD_GET:
			return "GET"
		HTTPClient.METHOD_POST:
			return "POST"
		HTTPClient.METHOD_PATCH:
			return "PATCH"
		HTTPClient.METHOD_DELETE:
			return "DELETE"
		_:
			return "HTTP"
