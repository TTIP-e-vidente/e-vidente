extends Node2D

@export var map_data: MapData

var level_node_scene := preload("res://mapas/LevelNode.tscn")


func _ready():
	_render_map()


func _render_map():
	for level_data in map_data.levels:
		var node = level_node_scene.instantiate()
		add_child(node)

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
