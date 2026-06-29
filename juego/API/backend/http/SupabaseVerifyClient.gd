class_name SupabaseVerifyClient
extends Node

## Cliente HTTP para Edge Functions de verificación de email en Supabase.
## Usa el JWT de Express (login) + anon key del proyecto Supabase.

const HTTP_TIMEOUT := 12.0

var functions_url: String = ""
var anon_key: String = ""
var _pool: Array[HTTPRequest] = []


func _init() -> void:
	functions_url = BackendConfig.obtener_supabase_functions_url()
	anon_key = BackendConfig.obtener_supabase_anon_key()


func solicitar_verificacion_email(token: String, mail_esperado: String = "") -> Dictionary:
	var body := {}
	var mail := mail_esperado.strip_edges()
	if not mail.is_empty():
		body["mail"] = mail
	return await _enviar_post("verify-email-request", token, JSON.stringify(body))


func confirmar_verificacion_email(token: String, codigo: String) -> Dictionary:
	var body := JSON.stringify({"code": codigo})
	return await _enviar_post("verify-email-confirm", token, body)


func verificar_salud_email() -> Dictionary:
	return await _enviar_get("verify-email-health", "")


func _enviar_post(function_name: String, token: String, body: String) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_POST, function_name, headers, body)


func _enviar_get(function_name: String, token: String) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_GET, function_name, headers, "")


func _armar_headers(token: String) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not anon_key.is_empty():
		headers.append("apikey: " + anon_key)
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	elif not anon_key.is_empty():
		headers.append("Authorization: Bearer " + anon_key)
	return headers


func _enviar_peticion(
	method: HTTPClient.Method,
	function_name: String,
	headers: PackedStringArray,
	body: String
) -> Dictionary:
	if functions_url.is_empty():
		return {
			"ok": false,
			"status": 0,
			"error": "Supabase Functions URL no configurada (sync:godot-config)",
			"code": "SUPABASE_NOT_CONFIGURED",
		}

	var url := functions_url + "/" + function_name
	var http := _adquirir_http()
	var start_error := http.request(url, headers, method, body)
	if start_error != OK:
		_liberar_http(http)
		return {
			"ok": false,
			"status": 0,
			"error": "HTTPRequest no pudo iniciarse (error %d)" % start_error,
		}

	var result: Array = await http.request_completed
	_liberar_http(http)
	return _parsear_respuesta(function_name, result)


func _adquirir_http() -> HTTPRequest:
	if not _pool.is_empty():
		return _pool.pop_back()
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	add_child(http)
	return http


func _liberar_http(http: HTTPRequest) -> void:
	_pool.push_back(http)


func _parsear_respuesta(function_name: String, result: Array) -> Dictionary:
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
			"error": "JSON inválido en respuesta Supabase",
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
			"[SupabaseVerifyClient] %s -> HTTP %d: %s"
			% [function_name, response_code, body_text]
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
			return "No se pudo conectar a Supabase Edge Functions"
		HTTPRequest.RESULT_TIMEOUT:
			return "Tiempo de espera agotado (Supabase)"
		_:
			return "Petición fallida a Supabase (result_code %d)" % result_code
