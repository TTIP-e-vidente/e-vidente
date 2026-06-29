class_name SupabaseEdgeClient
extends Node

## Cliente HTTP genérico para Supabase Edge Functions.
## Headers: apikey + Authorization (JWT de sesión o anon key).

const HTTP_TIMEOUT := 12.0
const RETRY_DELAYS_SEC := [0.5, 1.0]
const TRANSIENT_HTTP_STATUSES := [502, 503, 504]

var functions_url: String = ""
var anon_key: String = ""
var _pool: Array[HTTPRequest] = []


func _init() -> void:
	functions_url = BackendConfig.obtener_supabase_functions_url()
	anon_key = BackendConfig.obtener_supabase_anon_key()


func enviar_post(function_name: String, token: String, body: String) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_POST, function_name, headers, body)


func enviar_get(function_name: String, token: String, query_string: String = "") -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_GET, function_name, headers, "", query_string)


func enviar_patch(function_name: String, token: String, body: String) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_PATCH, function_name, headers, body)


func enviar_delete(function_name: String, token: String) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion(HTTPClient.METHOD_DELETE, function_name, headers, "")


func enviar_post_con_timeout(
	function_name: String,
	token: String,
	body: String,
	timeout: float
) -> Dictionary:
	var headers := _armar_headers(token)
	return await _enviar_peticion_con_timeout(
		HTTPClient.METHOD_POST,
		function_name,
		headers,
		body,
		"",
		timeout,
	)


func armar_url(function_name: String) -> String:
	return functions_url + "/" + function_name


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
	body: String,
	query_string: String = ""
) -> Dictionary:
	if functions_url.is_empty():
		return {
			"ok": false,
			"status": 0,
			"error": "Supabase Functions URL no configurada (sync:godot-config)",
			"code": "SUPABASE_NOT_CONFIGURED",
		}

	var url := armar_url(function_name)
	var qs := query_string.strip_edges()
	if qs.begins_with("?"):
		qs = qs.substr(1)
	if not qs.is_empty():
		url += "?" + qs

	var last := await _enviar_peticion_http(method, url, headers, body, function_name)
	for delay_sec in RETRY_DELAYS_SEC:
		if last.get("ok", false) or not _es_fallo_transitorio(last):
			break
		await get_tree().create_timer(delay_sec).timeout
		last = await _enviar_peticion_http(method, url, headers, body, function_name)
	return last


func _enviar_peticion_http(
	method: HTTPClient.Method,
	url: String,
	headers: PackedStringArray,
	body: String,
	function_name: String,
) -> Dictionary:
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


func _es_fallo_transitorio(resp: Dictionary) -> bool:
	if str(resp.get("code", "")) == "SUPABASE_NOT_CONFIGURED":
		return false
	var status := int(resp.get("status", 0))
	if status == 0:
		var result_code := int(resp.get("result_code", HTTPRequest.RESULT_SUCCESS))
		return (
			result_code == HTTPRequest.RESULT_CANT_CONNECT
			or result_code == HTTPRequest.RESULT_TIMEOUT
		)
	return status in TRANSIENT_HTTP_STATUSES


func _adquirir_http() -> HTTPRequest:
	if not _pool.is_empty():
		return _pool.pop_back()
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	add_child(http)
	return http


func _liberar_http(http: HTTPRequest) -> void:
	_pool.push_back(http)


func _enviar_peticion_con_timeout(
	method: HTTPClient.Method,
	function_name: String,
	headers: PackedStringArray,
	body: String,
	query_string: String,
	timeout: float
) -> Dictionary:
	if functions_url.is_empty():
		return {
			"ok": false,
			"status": 0,
			"error": "Supabase Functions URL no configurada (sync:godot-config)",
			"code": "SUPABASE_NOT_CONFIGURED",
		}

	var url := armar_url(function_name)
	var qs := query_string.strip_edges()
	if qs.begins_with("?"):
		qs = qs.substr(1)
	if not qs.is_empty():
		url += "?" + qs

	var last := await _enviar_peticion_http_con_timeout(
		method,
		url,
		headers,
		body,
		function_name,
		timeout,
	)
	if last.get("ok", false) or not _es_fallo_transitorio(last):
		return last
	await get_tree().create_timer(RETRY_DELAYS_SEC[0]).timeout
	return await _enviar_peticion_http_con_timeout(
		method,
		url,
		headers,
		body,
		function_name,
		timeout,
	)


func _enviar_peticion_http_con_timeout(
	method: HTTPClient.Method,
	url: String,
	headers: PackedStringArray,
	body: String,
	function_name: String,
	timeout: float,
) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var start_error := http.request(url, headers, method, body)
	if start_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"status": 0,
			"error": "HTTPRequest no pudo iniciarse (error %d)" % start_error,
		}
	var result: Array = await http.request_completed
	http.queue_free()
	return _parsear_respuesta(function_name, result)


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
			"[SupabaseEdgeClient] %s -> HTTP %d: %s"
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
