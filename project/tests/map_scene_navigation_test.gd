extends SceneTree

const SaveManagerScript := preload("res://interface/SaveManager.gd")
const MAP_SCENE := "res://mapas/MapScene.tscn"
const MODE_SELECTOR_SCENE := "res://niveles/selector.tscn"
const QUESTIONS_SCENE := "res://preguntas/pregunta.tscn"
const LEVEL_SCENE := "res://niveles/nivel_1/Level.tscn"
const EXPECTED_NODE_COUNT := 14
const TRACK_KEY_CELIAQUIA := "celiaquia"
const MAP_NODE_KIND_CHAPTER := "chapter"
const MAP_NODE_KIND_QUESTION := "question"

var SaveManager
var Global
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_prepare_test_environment()
	if failed:
		quit(1)
		return

	await _validate_map_contract_flow()
	if failed:
		await _quit()
		return

	await _validate_first_recipe_flow()
	if failed:
		await _quit()
		return

	await _validate_first_question_flow()
	if failed:
		await _quit()
		return

	await _validate_map_completion_popup()
	await _quit()


func _prepare_test_environment() -> void:
	_resolve_singletons()
	_assert(SaveManager != null, "No se encontro el autoload SaveManager")
	_assert(Global != null, "No se encontro el autoload Global")
	if failed:
		return

	_cleanup_test_files()


func _validate_map_contract_flow() -> void:
	await _go_to(MAP_SCENE, "Mapa de Celiaquia")
	_check_map_contract()


func _validate_first_recipe_flow() -> void:
	var first_recipe_node_definition: Dictionary = _get_map_node_definition(
		0,
		"chapter",
		"primer nodo de receta"
	)
	if failed:
		return

	current_scene._on_node_selected(first_recipe_node_definition)
	await _wait_for(LEVEL_SCENE, "Nivel de receta")
	_assert(Global.current_level == 1, "El primer nodo de receta deberia fijar el capitulo 1")
	if failed:
		return

	current_scene._on_atras_pressed()
	await _wait_for(MAP_SCENE, "Retorno al mapa desde receta")


func _validate_first_question_flow() -> void:
	var first_question_node_definition: Dictionary = _get_map_node_definition(
		1,
		"question",
		"primer nodo de pregunta"
	)
	if failed:
		return

	var expected_question_resource_path: String = str(
		first_question_node_definition.get("question_resource_path", "")
	).strip_edges()
	var expected_question_resource: Resource = load(expected_question_resource_path) as Resource
	_assert(
		expected_question_resource != null,
		"La pregunta del mapa deberia apuntar a un recurso cargable"
	)
	if failed:
		return

	current_scene._on_node_selected(first_question_node_definition)
	await _wait_for(QUESTIONS_SCENE, "Nivel de pregunta")
	_assert(
		current_scene.quiz != null and current_scene.quiz.theme.size() == 1,
		"La escena de preguntas deberia hidratar una sola pregunta desde el nodo del mapa"
	)
	if failed:
		return

	_assert(
		current_scene.quiz.theme[0].info_pregunta == expected_question_resource.info_pregunta,
		"La escena de preguntas deberia cargar la pregunta exacta configurada en el mapa"
	)
	current_scene._game_over()
	_assert(
		Global.is_question_completed(
			TRACK_KEY_CELIAQUIA,
			str(first_question_node_definition.get("question_key", ""))
		),
		"Completar una pregunta desde el mapa deberia persistir su progreso"
	)
	if failed:
		return

	current_scene._on_jugar_nuevamente_pressed()
	await _wait_for(MAP_SCENE, "Retorno al mapa desde pregunta")


func _validate_map_completion_popup() -> void:
	_cleanup_test_files()
	Global.set_progress_system_state(
		"map_completion",
		{
			"shown_tracks": {
				TRACK_KEY_CELIAQUIA: true
			}
		}
	)

	await _go_to(MAP_SCENE, "Mapa completo")
	_mark_all_map_nodes_as_completed(current_scene.get_playable_node_definitions())

	await _go_to(MAP_SCENE, "Mapa de Celiaquia completado")
	var completion_popup: Node = current_scene.get_node_or_null("CapituloCompletado")
	_assert(
		completion_popup != null,
		"El mapa completo deberia abrir la escena CapituloCompletado aunque la track ya estuviera marcada como mostrada"
	)
	if failed:
		return

	completion_popup.call("_on_continuar_pressed")
	await _wait_for(MODE_SELECTOR_SCENE, "Selector de modos desde popup de mapa completado")


func _mark_all_map_nodes_as_completed(node_definitions: Array) -> void:
	for raw_node_definition in node_definitions:
		if not raw_node_definition is Dictionary:
			continue
		_mark_single_map_node_as_completed(raw_node_definition as Dictionary)


func _mark_single_map_node_as_completed(node_definition: Dictionary) -> void:
	if _is_question_node_definition(node_definition):
		Global.mark_question_completed(
			TRACK_KEY_CELIAQUIA,
			str(node_definition.get("question_key", "")).strip_edges()
		)
		return

	Global.mark_level_completed(
		TRACK_KEY_CELIAQUIA,
		int(node_definition.get("level_number", 0))
	)


func _is_question_node_definition(node_definition: Dictionary) -> bool:
	return _get_node_kind(node_definition) == MAP_NODE_KIND_QUESTION


func _get_node_kind(node_definition: Dictionary) -> String:
	return str(node_definition.get("kind", "")).strip_edges()


func _get_map_node_definition(node_index: int, expected_kind: String, node_label: String) -> Dictionary:
	_assert(current_scene != null, "El mapa deberia seguir cargado antes de leer %s" % node_label)
	if failed:
		return {}

	_assert(
		current_scene.has_method("get_playable_node_definitions"),
		"El mapa deberia exponer get_playable_node_definitions antes de leer %s" % node_label
	)
	if failed:
		return {}

	var node_definitions: Array = current_scene.get_playable_node_definitions()
	_assert(
		node_index >= 0 and node_index < node_definitions.size(),
		"No se encontro %s dentro del contrato del mapa" % node_label
	)
	if failed:
		return {}

	var raw_node_definition: Variant = node_definitions[node_index]
	_assert(raw_node_definition is Dictionary, "%s deberia declararse como Dictionary" % node_label)
	if failed:
		return {}

	var node_definition: Dictionary = raw_node_definition as Dictionary
	var node_kind: String = _get_node_kind(node_definition)
	_assert(node_kind == expected_kind, "Se esperaba que %s fuera %s" % [node_label, expected_kind])
	return node_definition


func _go_to(scene_path: String, label: String) -> void:
	_assert(change_scene_to_file(scene_path) == OK, "No se pudo abrir %s" % label)
	if not failed:
		await _wait_for(scene_path, label)


func _wait_for(expected_path: String, label: String) -> void:
	for attempt_index in 60:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == expected_path:
			return
	_assert(false, "No se llego a %s (%s)" % [label, expected_path])


func _check_map_contract() -> void:
	var rendered_nodes: Node2D = current_scene.call("get_nodes_container") as Node2D
	_assert(rendered_nodes != null, "El mapa deberia exponer get_nodes_container")
	_assert(
		current_scene.has_method("get_playable_node_definitions"),
		"El mapa deberia exponer get_playable_node_definitions"
	)
	if rendered_nodes == null or not current_scene.has_method("get_playable_node_definitions"):
		return

	var node_definitions: Array = current_scene.get_playable_node_definitions()
	_assert(
		node_definitions.size() == EXPECTED_NODE_COUNT,
		"El mapa de Celiaquia deberia declarar %d nodos" % EXPECTED_NODE_COUNT
	)
	_assert(
		rendered_nodes.get_child_count() == EXPECTED_NODE_COUNT,
		"El mapa de Celiaquia deberia renderizar %d nodos" % EXPECTED_NODE_COUNT
	)
	for raw_node_definition in node_definitions:
		_assert(raw_node_definition is Dictionary, "Cada nodo del mapa deberia declararse como Dictionary")
		if not raw_node_definition is Dictionary:
			continue
		_check_single_node_contract(raw_node_definition as Dictionary)


func _check_single_node_contract(node_definition: Dictionary) -> void:
	var node_kind: String = _get_node_kind(node_definition)
	_assert(
		node_kind == MAP_NODE_KIND_CHAPTER or node_kind == MAP_NODE_KIND_QUESTION,
		"Cada nodo del mapa deberia declarar si es receta o pregunta"
	)
	if failed:
		return

	if node_kind == MAP_NODE_KIND_CHAPTER:
		_assert(
			int(node_definition.get("level_number", 0)) > 0,
			"Los nodos de receta deberian apuntar a un capitulo valido"
		)
		return

	_assert(
		not str(node_definition.get("question_resource_path", "")).strip_edges().is_empty(),
		"Los nodos de pregunta deberian apuntar a un recurso concreto"
	)


func _resolve_singletons() -> void:
	if SaveManager == null:
		SaveManager = root.get_node_or_null("/root/SaveManager")
	if Global == null:
		Global = root.get_node_or_null("/root/Global")


func _cleanup_test_files() -> void:
	Global.reset_progress()
	for relative_path in [
		SaveManagerScript.SAVE_PATH,
		SaveManagerScript.TEMP_SAVE_PATH,
		SaveManagerScript.BACKUP_SAVE_PATH
	]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	SaveManager.load_data()


func _quit() -> void:
	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("MAP SCENE TEST FAILED: %s" % message)