extends SceneTree

const QUIZ_JSON_PATH := "res://preguntas/json_nodos/ejemplo_nodo_celiaquia.json"
const DRAG_DROP_JSON_PATH := "res://preguntas/json_nodos/ejemplo_arrastrar.json"
const FLAT_QUIZ_JSON_PATH := "user://node_content_loader_flat_quiz.json"
const SELECT_JSON_PATH := "res://preguntas/json_nodos/ejemplo_seleccionar.json"
const UNSUPPORTED_JSON_PATH := "res://preguntas/json_nodos/ejemplo_titulo.json"
const MISSING_CONTENT_JSON_PATH := "user://node_content_loader_missing_content.json"
const MISSING_JSON_PATH := "user://node_content_loader_missing.json"

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_valid_quiz_json()
	_check_valid_drag_drop_json()
	_check_missing_file()
	_check_missing_content()
	_check_flat_quiz_normalization()
	_check_legacy_select_option()
	_check_unsupported_mode()
	_cleanup_temp_fixtures()
	await process_frame
	quit(1 if failed else 0)


func _check_valid_quiz_json() -> void:
	var result: Dictionary = NodeContentLoader.load_node(QUIZ_JSON_PATH)
	_check(bool(result.get("ok", false)), "El loader deberia cargar el quiz oficial.")
	if not bool(result.get("ok", false)):
		return

	var content: Dictionary = result["data"]
	_check(content.get("mode", "") == NodeContentLoader.MODE_QUIZ_CHOICE, "Debe devolver el modo quiz_choice.")
	_check(content.has("content"), "Debe devolver content.")
	var quiz_content: Dictionary = content.get("content", {})
	_check(quiz_content.get("question", "") == "El maiz contiene gluten?", "Debe devolver la pregunta.")
	_check((quiz_content.get("wrong_options", []) as Array).size() == 3, "Debe devolver opciones incorrectas.")


func _check_valid_drag_drop_json() -> void:
	var result: Dictionary = NodeContentLoader.load_node(DRAG_DROP_JSON_PATH)
	_check(bool(result.get("ok", false)), "El loader deberia cargar el drag_drop oficial.")
	if not bool(result.get("ok", false)):
		return

	var content: Dictionary = result["data"]
	_check(content.get("mode", "") == NodeContentLoader.MODE_DRAG_DROP, "Debe devolver el modo drag_drop.")
	var drag_content: Dictionary = content.get("content", {})
	_check((drag_content.get("targets", []) as Array).size() == 1, "Debe devolver targets.")
	_check((drag_content.get("items", []) as Array).size() == 2, "Debe devolver items.")


func _check_missing_file() -> void:
	var result: Dictionary = NodeContentLoader.load_node(MISSING_JSON_PATH)
	_check(not bool(result.get("ok", false)), "Un archivo inexistente no deberia cargar.")
	_check(str(result.get("error", "")).contains("No existe el JSON"), "Debe informar archivo inexistente.")


func _check_missing_content() -> void:
	var file: FileAccess = FileAccess.open(MISSING_CONTENT_JSON_PATH, FileAccess.WRITE)
	_check(file != null, "Se deberia poder crear un fixture temporal invalido.")
	if file == null:
		return

	file.store_string(
		"{\"id\":\"sin_content\",\"theme\":\"celiaquia\",\"title\":\"Nodo roto\",\"difficulty\":\"easy\",\"mode\":\"quiz_choice\"}"
	)
	file.close()

	var result: Dictionary = NodeContentLoader.load_node(MISSING_CONTENT_JSON_PATH)
	_check(not bool(result.get("ok", false)), "Un JSON sin content no deberia cargar.")
	_check(str(result.get("error", "")).contains("content"), "Debe informar que falta content.")


func _check_flat_quiz_normalization() -> void:
	var file: FileAccess = FileAccess.open(FLAT_QUIZ_JSON_PATH, FileAccess.WRITE)
	_check(file != null, "Se deberia poder crear un fixture quiz plano.")
	if file == null:
		return

	file.store_string(
		"{\"id\":\"quiz_plano\",\"theme\":\"celiaquia\",\"title\":\"Quiz plano\",\"difficulty\":\"easy\",\"mode\":\"quiz_choice\",\"question\":\"El maiz contiene gluten?\",\"correct_answer\":\"No\",\"wrong_options\":[\"Si\",\"Tal vez\"],\"visual_resource\":\"\"}"
	)
	file.close()

	var result: Dictionary = NodeContentLoader.load_node(FLAT_QUIZ_JSON_PATH)
	_check(bool(result.get("ok", false)), "El formato quiz plano deberia normalizarse.")
	if not bool(result.get("ok", false)):
		return

	var content: Dictionary = result["data"]
	_check(content.has("content"), "El formato plano deberia convertirse a content.")
	_check(content.get("mode", "") == NodeContentLoader.MODE_QUIZ_CHOICE, "Debe quedar como quiz_choice.")


func _check_legacy_select_option() -> void:
	var result: Dictionary = NodeContentLoader.load_node(SELECT_JSON_PATH)
	_check(bool(result.get("ok", false)), "select_option legacy deberia seguir cargando.")
	if not bool(result.get("ok", false)):
		return

	var content: Dictionary = result["data"]
	_check(content.get("mode", "") == NodeContentLoader.MODE_QUIZ_CHOICE, "select_option deberia normalizarse.")
	var quiz_content: Dictionary = content.get("content", {})
	_check((quiz_content.get("wrong_options", []) as Array).size() == 2, "Debe reconstruir opciones incorrectas.")


func _check_unsupported_mode() -> void:
	var result: Dictionary = NodeContentLoader.load_node(UNSUPPORTED_JSON_PATH)
	_check(not bool(result.get("ok", false)), "Un modo no soportado no deberia cargar.")
	_check(str(result.get("error", "")).contains("Modo no soportado"), "Debe informar el modo invalido.")


func _cleanup_temp_fixtures() -> void:
	for temp_path in [MISSING_CONTENT_JSON_PATH, FLAT_QUIZ_JSON_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(temp_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("NODE CONTENT LOADER TEST FAILED: %s" % message)
