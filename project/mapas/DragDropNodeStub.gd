extends Control

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DEFAULT_RETURN_SCENE_PATH := GameSceneRouter.MAP_SCENE_PATH

var _ruta_escena_retorno: String = DEFAULT_RETURN_SCENE_PATH

@onready var _label_titulo: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _label_instruccion: Label = $MarginContainer/VBoxContainer/InstructionLabel
@onready var _label_resumen: Label = $MarginContainer/VBoxContainer/SummaryLabel


func _ready() -> void:
	var session_state: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	var node_content: Dictionary = session_state.get("node_data", {})
	var content: Dictionary = node_content.get("content", {})

	_ruta_escena_retorno = str(
		session_state.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _ruta_escena_retorno.is_empty():
		_ruta_escena_retorno = DEFAULT_RETURN_SCENE_PATH

	_label_titulo.text = str(node_content.get("title", "Nodo drag_drop")).strip_edges()
	_label_instruccion.text = str(
		content.get("instruction", "Fallback seguro de drag_drop para la demo.")
	).strip_edges()
	_label_resumen.text = "Targets: %d | Items: %d\nFallback seguro para la demo." % [
		(content.get("targets", []) as Array).size(),
		(content.get("items", []) as Array).size()
	]


func _on_back_button_pressed() -> void:
	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_ruta_escena_retorno)
