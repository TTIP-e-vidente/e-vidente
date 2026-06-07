class_name BackendApiClient
extends Node

const DEFAULT_BASE_URL := "http://localhost:3000"
const HTTP_TIMEOUT := 3.0
const AVATAR_UPLOAD_TIMEOUT := 30.0

var base_url: String = DEFAULT_BASE_URL
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


func verificar_salud_api() -> Dictionary:
	return await _obtener_json("/health", "")


func verificar_salud_db() -> Dictionary:
	return await _obtener_json("/health/db", "")


func iniciar_sesion(usuario_o_mail: String, clave: String) -> Dictionary:
	var body := JSON.stringify({
		"usernameOrMail": usuario_o_mail,
		"password": clave,
	})
	return await _enviar_post("/auth/login", "", body)


func registrar_cuenta(
	usuario: String,
	nombre: String,
	mail: String,
	clave: String,
	fecha_nacimiento: Variant = null
) -> Dictionary:
	var payload := {
		"username": usuario,
		"name": nombre,
		"mail": mail,
		"password": clave,
	}
	if fecha_nacimiento != null:
		var birth_date := str(fecha_nacimiento).strip_edges()
		if not birth_date.is_empty():
			payload["birth_date"] = birth_date
	return await _enviar_post("/auth/register", "", JSON.stringify(payload))


func obtener_mi_usuario(token: String) -> Dictionary:
	return await _obtener_json("/auth/me", token)


func guardar_progreso(token: String, resumen_partida: Dictionary) -> Dictionary:
	var body := JSON.stringify(resumen_partida)
	return await _enviar_post("/player/me/progress", token, body)


func guardar_progreso_batch(token: String, items: Array) -> Dictionary:
	var body := JSON.stringify({"items": items})
	return await _enviar_post("/player/me/progress/batch", token, body)


func obtener_progreso(token: String) -> Dictionary:
	return await _obtener_json("/player/me/progress", token)


func subir_avatar(token: String, data: String, mime_type: String) -> Dictionary:
	# Avatar usa timeout largo por el tamaño del payload base64.
	var body := JSON.stringify({"data": data, "mimeType": mime_type})
	var headers := _armar_headers(token)
	return await _enviar_peticion_con_timeout(
		HTTPClient.METHOD_POST, "/player/me/avatar", headers, body, AVATAR_UPLOAD_TIMEOUT
	)


func descargar_avatar(token: String) -> Dictionary:
	return await _obtener_json("/player/me/avatar", token)


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
		_:
			return "HTTP"
