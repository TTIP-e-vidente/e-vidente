extends Control

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DEFAULT_RETURN_SCENE := GameSceneRouter.MAP_SCENE_PATH

var _ruta_escena_retorno: String = DEFAULT_RETURN_SCENE

@onready var _label_titulo: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _label_instruccion: Label = $MarginContainer/VBoxContainer/InstructionLabel
@onready var _label_resumen: Label = $MarginContainer/VBoxContainer/SummaryLabel


func _ready() -> void:
	var contexto_sesion: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	var datos_nodo: Dictionary = contexto_sesion.get("node_data", {})
	var contenido_nodo: Dictionary = datos_nodo.get("content", {})

	_ruta_escena_retorno = GameSceneRouter.read_return_to(
		contexto_sesion,
		DEFAULT_RETURN_SCENE
	)
	if _ruta_escena_retorno.is_empty():
		_ruta_escena_retorno = DEFAULT_RETURN_SCENE

	_label_titulo.text = str(datos_nodo.get("title", "Nodo drag_drop")).strip_edges()
	_label_instruccion.text = str(
		contenido_nodo.get("instruction", "Fallback seguro de drag_drop para la demo.")
	).strip_edges()
	_label_resumen.text = "Targets: %d | Items: %d\nFallback seguro para la demo." % [
		(contenido_nodo.get("targets", []) as Array).size(),
		(contenido_nodo.get("items", []) as Array).size()
	]


func _on_back_button_pressed() -> void:
	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_ruta_escena_retorno)
