extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const STREAK_SEAL_SCENE := preload(
	"res://interface/components/StreakDailySeal.tscn"
)
const PROFILE_BUTTON_SCRIPT := preload(
	"res://interface/components/ProfileProgressButton.gd"
)
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const LEVEL_NODE_SCENE := preload("res://mapas/LevelNode.tscn")
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA
const NODE_KIND_CHAPTER := "chapter"
const NODE_KIND_QUESTION := "question"

@export var map_data: MapData


@onready var nodes_container: Node2D = $NodesContainer


func _ready() -> void:
	_position_back_button()
	_build_hud()
	Global.clear_active_question_session()
	_render_map_nodes()


func _position_back_button() -> void:
	var btn := $"Atrás" as Button
	btn.scale = Vector2(0.52, 0.455)
	btn.offset_left = 54.0
	btn.offset_top = 636.0
	btn.offset_right = 283.0
	btn.offset_bottom = 904.0


func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 75
	add_child(hud_layer)

	var hud_root: Control = _build_hud_root()
	hud_layer.add_child(hud_root)
	_add_streak_seal_to_hud(hud_root)
	_add_profile_button_to_hud(hud_root)


func _build_hud_root() -> Control:
	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hud_root


func _add_streak_seal_to_hud(hud_root: Control) -> void:
	var streak_seal := STREAK_SEAL_SCENE.instantiate() as Control
	if streak_seal != null:
		streak_seal.anchor_left = 0.0
		streak_seal.anchor_top = 0.0
		streak_seal.anchor_right = 0.0
		streak_seal.anchor_bottom = 0.0
		streak_seal.offset_left = 16.0
		streak_seal.offset_top = 16.0
		streak_seal.offset_right = 152.0
		streak_seal.offset_bottom = 152.0
		hud_root.add_child(streak_seal)


func _add_profile_button_to_hud(hud_root: Control) -> void:
	var profile_btn := Button.new()
	profile_btn.script = PROFILE_BUTTON_SCRIPT
	profile_btn.anchor_left = 1.0
	profile_btn.anchor_top = 0.0
	profile_btn.anchor_right = 1.0
	profile_btn.anchor_bottom = 0.0
	profile_btn.offset_left = -152.0
	profile_btn.offset_top = 16.0
	profile_btn.offset_right = -16.0
	profile_btn.offset_bottom = 84.0
	profile_btn.tooltip_text = "Mi progreso"
	profile_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(profile_btn)

func _render_map_nodes() -> void:
	_clear_rendered_nodes()

	if map_data == null:
		push_warning("MapScene: No hay map_data asignado, saltando render.")
		return

	var playable_node_definitions: Array[Dictionary] = _build_playable_node_definitions()
	for node_index in range(playable_node_definitions.size()):
		var node_definition: Dictionary = playable_node_definitions[node_index]
		var map_node: Node2D = _build_map_node(
			playable_node_definitions,
			node_index,
			node_definition
		)
		nodes_container.add_child(map_node)


func _clear_rendered_nodes() -> void:
	for child in nodes_container.get_children():
		child.queue_free()


func _build_playable_node_definitions() -> Array[Dictionary]:
	# Filtramos temprano los nodos rotos para que el render solo recorra datos jugables.
	var playable_node_definitions: Array[Dictionary] = []
	for raw_node_definition in map_data.levels:
		if not raw_node_definition is Dictionary:
			push_warning("MapScene: Se encontro una entrada invalida en map_data.levels.")
			continue

		var node_definition: Dictionary = (raw_node_definition as Dictionary).duplicate(true)
		if not _node_has_destination(node_definition):
			push_warning("MapScene: Hay un nodo sin destino asignado en el recurso del mapa.")
			continue

		playable_node_definitions.append(node_definition)

	return playable_node_definitions


func _build_map_node(
	playable_node_definitions: Array[Dictionary],
	node_index: int,
	node_definition: Dictionary
) -> Node2D:
	var map_node: Node2D = LEVEL_NODE_SCENE.instantiate()
	var node_completed: bool = _is_node_completed(node_definition)
	var node_unlocked: bool = _is_node_unlocked_by_order(
		playable_node_definitions,
		node_index,
		node_completed
	)

	map_node.position = node_definition.get("pos", Vector2.ZERO)
	map_node.setup(node_definition, node_unlocked, node_completed)
	map_node.level_selected.connect(_on_level_selected)
	return map_node


func _on_level_selected(level_target: Variant) -> void:
	# El flujo moderno manda el diccionario completo del nodo.
	# El smoke viejo puede seguir llamando con una ruta simple.
	if level_target is Dictionary:
		_open_node_from_map(level_target)
		return

	var scene_path := str(level_target).strip_edges()
	if scene_path.is_empty():
		push_warning("MapScene: Se intento abrir un destino vacio desde el mapa.")
		return

	get_tree().change_scene_to_file(scene_path)


func _open_node_from_map(node_definition: Dictionary) -> void:
	var track_key: String = _resolve_track_key(node_definition)

	if _is_question_node(node_definition):
		_open_question_node(track_key, node_definition)
		return

	_open_chapter_node(track_key, node_definition)


func _open_question_node(track_key: String, node_definition: Dictionary) -> void:
	var question_session_state: Dictionary = _build_question_session_state(track_key, node_definition)
	Global.set_active_question_session(question_session_state)
	GameSceneRouter.go_to_questions(get_tree())


func _build_question_session_state(track_key: String, node_definition: Dictionary) -> Dictionary:
	return {
		"track_key": track_key,
		"nivel_id": int(node_definition.get("question_number", node_definition.get("id", 1))),
		"question_key": str(node_definition.get("question_key", "")).strip_edges(),
		"question_resource_path": str(node_definition.get("question_resource_path", "")).strip_edges(),
		"return_scene_path": GameSceneRouter.MAP_SCENE_PATH
	}


func _open_chapter_node(track_key: String, node_definition: Dictionary) -> void:
	GameSceneRouter.go_to_track_level(
		get_tree(),
		track_key,
		int(node_definition.get("level_number", 1))
	)


func _node_has_destination(node_definition: Dictionary) -> bool:
	if _is_question_node(node_definition):
		return _question_node_has_destination(node_definition)

	if not _is_chapter_node(node_definition):
		return false

	return _chapter_node_has_destination(node_definition)


func _question_node_has_destination(node_definition: Dictionary) -> bool:
	return not str(node_definition.get("question_resource_path", "")).strip_edges().is_empty()


func _chapter_node_has_destination(node_definition: Dictionary) -> bool:
	return GameTrackCatalog.has_track(_resolve_track_key(node_definition)) and int(
		node_definition.get("level_number", 0)
	) > 0


func _is_node_unlocked_by_order(
	playable_node_definitions: Array[Dictionary],
	index: int,
	completed: bool
) -> bool:
	if completed or index <= 0:
		return true
	return _is_node_completed(playable_node_definitions[index - 1])


func _is_node_completed(node_definition: Dictionary) -> bool:
	var track_key: String = _resolve_track_key(node_definition)
	if _is_question_node(node_definition):
		return _is_question_node_completed(track_key, node_definition)
	return Global.is_level_completed(track_key, int(node_definition.get("level_number", 0)))


func _is_question_node_completed(track_key: String, node_definition: Dictionary) -> bool:
	return Global.is_question_completed(
		track_key,
		str(node_definition.get("question_key", "")).strip_edges()
	)


func _resolve_track_key(node_definition: Dictionary) -> String:
	var raw_track_key := str(node_definition.get("track_key", DEFAULT_TRACK_KEY)).strip_edges()
	if GameTrackCatalog.has_track(raw_track_key):
		return raw_track_key
	return DEFAULT_TRACK_KEY


func _is_question_node(node_definition: Dictionary) -> bool:
	return _get_node_kind(node_definition) == NODE_KIND_QUESTION


func _is_chapter_node(node_definition: Dictionary) -> bool:
	return _get_node_kind(node_definition) == NODE_KIND_CHAPTER


func _get_node_kind(node_definition: Dictionary) -> String:
	return str(node_definition.get("kind", NODE_KIND_CHAPTER)).strip_edges().to_lower()


func _on_atrás_pressed() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
