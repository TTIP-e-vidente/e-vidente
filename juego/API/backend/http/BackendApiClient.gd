class_name BackendApiClient
extends Node

const DEFAULT_BASE_URL := "http://localhost:3000"

var base_url: String = DEFAULT_BASE_URL


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
	edad: Variant = null
) -> Dictionary:
	var payload := {
		"username": usuario,
		"name": nombre,
		"mail": mail,
		"password": clave,
	}
	if edad != null:
		payload["age"] = edad
	return await _enviar_post("/auth/register", "", JSON.stringify(payload))


func obtener_mi_usuario(token: String) -> Dictionary:
	return await _obtener_json("/auth/me", token)


func guardar_progreso(token: String, resumen_partida: Dictionary) -> Dictionary:
	var body := JSON.stringify(resumen_partida)
	return await _enviar_post("/player/me/progress", token, body)


func obtener_progreso(token: String) -> Dictionary:
	return await _obtener_json("/player/me/progress", token)


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
	var http := HTTPRequest.new()
	http.timeout = 3.0
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

	var result_code: int = result[0]
	var response_code: int = result[1]
	var body_bytes: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		var connection_error := _mensaje_error_conexion(result_code)
		return {
			"ok": false,
			"status": 0,
			"result_code": result_code,
			"error": connection_error,
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
