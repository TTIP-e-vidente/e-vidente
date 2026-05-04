extends SceneTree

const MAP_SCENE := "res://mapas/MapScene.tscn"
const TRACK_KEY := "celiaquia"
const FIRST_NODE_KEY := "receta_1_desayuno"
const NODE_JSON_ROOT := "res://contenido/nodos/"
const QUIZ_FOLDER := "/preguntas/"
const DRAG_FOLDER := "/arrastre/"

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var global_state = root.get_node_or_null("/root/Global")
	_check(global_state != null, "Autoload Global no encontrado")
	if failed:
		await _quit()
		return

	global_state.reiniciar_progreso()
	_check(change_scene_to_file(MAP_SCENE) == OK, "No se pudo abrir el mapa")
	if failed:
		await _quit()
		return

	await process_frame
	await process_frame

	var scene := current_scene
	_check(
		scene != null and scene.has_method("refresh_node_states"),
		"MapScene deberia exponer refresh_node_states"
	)
	if failed:
		await _quit()
		return

	var board = scene.get_node_or_null("MapBoard")
	_check(board != null and board.has_method("obtener_nodos_runtime_mapa"), "MapBoard invalido")
	if failed:
		await _quit()
		return

	var visual_nodes: Array = board.call("obtener_nodos_runtime_mapa")
	var map_nodes: Array = scene.get("nodos_mapa")
	_check(map_nodes.size() == 25, "El JSON de celiaquia deberia cargar 25 nodos")
	_assert_map_contract(map_nodes)
	_check(
		visual_nodes.size() == map_nodes.size(),
		"El tablero visual deberia representar todos los nodos del JSON"
	)
	if failed:
		await _quit()
		return

	_assert_visual_state(visual_nodes[0], false, true, true, "available", "Primer nodo inicial")
	_assert_visual_state(visual_nodes[1], false, false, false, "locked", "Segundo nodo inicial")
	_assert_visual_state(visual_nodes[2], false, false, false, "locked", "Tercer nodo inicial")
	if failed:
		await _quit()
		return

	global_state.marcar_nodo_jugable_completado(TRACK_KEY, FIRST_NODE_KEY)
	scene.call("refresh_node_states")
	await process_frame

	visual_nodes = board.call("obtener_nodos_runtime_mapa")
	_assert_visual_state(visual_nodes[0], true, true, true, "completed", "Primer nodo completado")
	_assert_visual_state(
		visual_nodes[1],
		false,
		true,
		true,
		"available",
		"Segundo nodo desbloqueado"
	)
	_assert_visual_state(visual_nodes[2], false, false, false, "locked", "Tercer nodo bloqueado")
	if failed:
		await _quit()
		return

	for map_node in map_nodes:
		if map_node == null:
			continue
		global_state.marcar_nodo_jugable_completado(TRACK_KEY, str(map_node.node_key))

	scene.call("volver_al_mapa")
	await process_frame
	await process_frame

	visual_nodes = board.call("obtener_nodos_runtime_mapa")
	_assert_visual_state(visual_nodes[24], true, true, true, "completed", "Ultimo nodo completado")
	_check(_count_completion_popups(scene) == 1, "El popup de mapa completo no deberia duplicarse")

	await _quit()


func _assert_map_contract(map_nodes: Array) -> void:
	var seen_node_keys: Dictionary = {}
	for index in range(map_nodes.size()):
		var map_node = map_nodes[index] as MapNodeData
		_check(map_node != null, "Nodo %d del mapa no deberia ser null" % (index + 1))
		if map_node == null:
			return

		var node_key: String = map_node.node_key.strip_edges()
		var node_label: String = "Nodo %d" % (index + 1)
		_check(not node_key.is_empty(), "%s sin node_key" % node_label)
		if node_key.is_empty():
			return
		_check(not seen_node_keys.has(node_key), "node_key duplicado: %s" % node_key)
		seen_node_keys[node_key] = true

		_check(map_node.is_supported_mode(), "%s con mode invalido: %s" % [node_key, map_node.mode])
		_check(map_node.has_content_path(), "%s sin json_path" % node_key)

		var json_path: String = map_node.json_path.strip_edges()
		_check(
			json_path.begins_with(NODE_JSON_ROOT),
			"%s debe apuntar a %s" % [node_key, NODE_JSON_ROOT]
		)
		_check(FileAccess.file_exists(json_path), "%s apunta a un json_path inexistente" % node_key)

		match map_node.mode:
			MapNodeData.MODE_QUIZ_CHOICE:
				_check(
					json_path.contains(QUIZ_FOLDER),
					"%s deberia vivir en %s" % [node_key, QUIZ_FOLDER]
				)
			MapNodeData.MODE_DRAG_DROP:
				_check(
					json_path.contains(DRAG_FOLDER),
					"%s deberia vivir en %s" % [node_key, DRAG_FOLDER]
				)


func _assert_visual_state(
	visual_node: Node,
	expected_completed: bool,
	expected_unlocked: bool,
	expected_can_play: bool,
	expected_visual_state: String,
	label: String
) -> void:
	_check(visual_node != null, "%s no existe" % label)
	if visual_node == null:
		return

	_check(
		bool(visual_node.get("completed")) == expected_completed,
		"%s: completed inesperado" % label
	)
	_check(
		bool(visual_node.get("unlocked")) == expected_unlocked,
		"%s: unlocked inesperado" % label
	)
	_check(
		bool(visual_node.get("can_play")) == expected_can_play,
		"%s: can_play inesperado" % label
	)
	_check(
		str(visual_node.get("visual_state")) == expected_visual_state,
		"%s: visual_state inesperado" % label
	)

	var button := visual_node.get_node_or_null("Button") as TextureButton
	_check(button != null, "%s deberia exponer Button" % label)
	if button != null:
		_check(
			button.disabled == not expected_can_play,
			"%s: disabled inesperado" % label
		)


func _count_completion_popups(scene: Node) -> int:
	var popup_count := 0
	for child in scene.get_children():
		if child.get_script() == null:
			continue
		var script_path: String = str(child.get_script().get_path())
		if script_path.ends_with("capitulo_completado.gd"):
			popup_count += 1
	return popup_count


func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failed = true
	push_error(message)


func _quit() -> void:
	await process_frame
	quit(1 if failed else 0)