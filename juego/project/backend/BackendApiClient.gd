class_name BackendApiClient
extends Node

const DEFAULT_BASE_URL := "http://localhost:3000"

## URL base del backend. Modificar antes de hacer llamadas si el servidor
## corre en otro host o puerto.
var base_url: String = DEFAULT_BASE_URL


# ── Endpoints públicos ──────────────────────────────────────────────────────

## POST /auth/login
## Devuelve { ok, status, data: { token, user: { id, username, ... } } }
func login(username_or_mail: String, password: String) -> Dictionary:
	var body := JSON.stringify({
		"username": username_or_mail,
		"password": password,
	})
	return await _post("/auth/login", "", body)


## POST /auth/register
func register(
	username: String,
	name: String,
	mail: String,
	password: String,
	age: int = 0
) -> Dictionary:
	var body := JSON.stringify({
		"username": username,
		"name": name,
		"mail": mail,
		"password": password,
		"age": age,
	})
	return await _post("/auth/register", "", body)


## GET /auth/me  — requiere token válido
func get_me(token: String) -> Dictionary:
	return await _get_json("/auth/me", token)


## POST /player/me/progress  — requiere token válido
## run_summary debe ser un Dictionary construido con RunSummaryBuilder.build()
func save_progress(token: String, run_summary: Dictionary) -> Dictionary:
	var body := JSON.stringify(run_summary)
	return await _post("/player/me/progress", token, body)


## GET /player/me/progress  — requiere token válido
func get_progress(token: String) -> Dictionary:
	return await _get_json("/player/me/progress", token)


# ── Helpers HTTP internos ───────────────────────────────────────────────────

func _post(endpoint: String, token: String, body: String) -> Dictionary:
	var headers := _build_headers(token)
	return await _send_request(HTTPClient.METHOD_POST, endpoint, headers, body)


func _get_json(endpoint: String, token: String) -> Dictionary:
	var headers := _build_headers(token)
	return await _send_request(HTTPClient.METHOD_GET, endpoint, headers, "")


func _build_headers(token: String) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	return headers


## Crea un HTTPRequest temporal, dispara la petición y devuelve el resultado
## parseado. El nodo HTTPRequest se libera al terminar.
func _send_request(
	method: HTTPClient.Method,
	endpoint: String,
	headers: PackedStringArray,
	body: String
) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var start_error := http.request(base_url + endpoint, headers, method, body)
	if start_error != OK:
		http.queue_free()
		return {
			"ok": false,
			"status": 0,
			"error": "HTTPRequest no pudo iniciarse (error %d)" % start_error,
		}

	# Espera la señal request_completed (no bloquea el hilo principal)
	var result: Array = await http.request_completed
	http.queue_free()

	# result = [result_code, response_code, headers, body_bytes]
	var result_code: int = result[0]
	var response_code: int = result[1]
	var body_bytes: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status": response_code,
			"error": "Petición fallida (HTTPRequest result_code %d)" % result_code,
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
	return {
		"ok": is_ok,
		"status": response_code,
		"data": json.data,
	}
