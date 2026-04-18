extends Node2D

@export var map_data: MapData
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
var level_node_scene := preload("res://mapas/LevelNode.tscn")

@onready var nodes_container = $NodesContainer

func _ready():
	_render_map()

func _render_map():
	if map_data == null:
		push_warning("MapScene: No hay map_data asignado, saltando render.")
		return

	for level_data in map_data.levels:
		var node = level_node_scene.instantiate()
		nodes_container.add_child(node)

		node.position = level_data.pos

		var unlocked := _is_level_unlocked(level_data.id)
		node.setup(level_data, unlocked)

		node.level_selected.connect(_on_level_selected)

func _on_level_selected(scene_path: String):
	get_tree().change_scene_to_file(scene_path)

func _is_level_unlocked(id: int) -> bool:
	if id == 1:
		return true
	return id <= Global.current_level

func _on_atrás_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())
