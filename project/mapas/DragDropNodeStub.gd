extends Control

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DEFAULT_RETURN_SCENE_PATH := GameSceneRouter.MAP_SCENE_PATH

var _return_scene_path: String = DEFAULT_RETURN_SCENE_PATH

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _instruction_label: Label = $MarginContainer/VBoxContainer/InstructionLabel
@onready var _summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel


func _ready() -> void:
	var session_state: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	var node_content: Dictionary = session_state.get("node_data", {})
	var content: Dictionary = node_content.get("content", {})

	_return_scene_path = str(
		session_state.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH

	_title_label.text = str(node_content.get("title", "Nodo drag_drop")).strip_edges()
	_instruction_label.text = str(
		content.get("instruction", "Fallback seguro de drag_drop para la demo.")
	).strip_edges()
	_summary_label.text = "Targets: %d | Items: %d\nFallback seguro para la demo." % [
		(content.get("targets", []) as Array).size(),
		(content.get("items", []) as Array).size()
	]


func _on_back_button_pressed() -> void:
	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_return_scene_path)
