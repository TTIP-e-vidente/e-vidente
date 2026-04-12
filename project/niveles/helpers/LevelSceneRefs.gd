extends RefCounted

var _manager


func _init(manager) -> void:
	_manager = manager


func bind_level_scene_nodes() -> bool:
	var level_root: Node = _resolve_level_root()
	if level_root == null:
		return false
	_resolve_missing_level_scene_nodes(level_root)
	if _has_required_level_scene_nodes():
		return true
	push_error(
		"ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual."
	)
	return false


func apply_run_textures_to_scene(level_resource: LevelResource, run_data: Dictionary) -> void:
	_assign_run_textures_to_level_resource(level_resource, run_data)
	_manager.meal_sprite.texture = level_resource.comida
	_manager.condition_sprite.texture = level_resource.condicion
	_manager.teaching_sprite.texture = level_resource.ensenanza


func _resolve_level_root() -> Node:
	var level_root: Node = _manager.get_parent()
	if level_root != null:
		return level_root
	push_error("ManagerLevel no encontro la escena de nivel contenedora.")
	return null


func _resolve_missing_level_scene_nodes(level_root: Node) -> void:
	if not is_instance_valid(_manager.plato):
		_manager.plato = level_root.get_node_or_null("Plato") as Plato
	if not is_instance_valid(_manager.meal_sprite):
		_manager.meal_sprite = level_root.get_node_or_null("Globo texto/Meal") as Sprite2D
	if not is_instance_valid(_manager.condition_sprite):
		_manager.condition_sprite = level_root.get_node_or_null(
			"Globo texto/Condition"
		) as Sprite2D
	if not is_instance_valid(_manager.teaching_sprite):
		_manager.teaching_sprite = level_root.get_node_or_null("Ensenanza") as Sprite2D


func _has_required_level_scene_nodes() -> bool:
	return (
		is_instance_valid(_manager.plato)
		and is_instance_valid(_manager.meal_sprite)
		and is_instance_valid(_manager.condition_sprite)
		and is_instance_valid(_manager.teaching_sprite)
	)


func _assign_run_textures_to_level_resource(
	level_resource: LevelResource,
	run_data: Dictionary
) -> void:
	level_resource.comida = Global.resolve_texture(run_data.get("meal_texture_path", ""))
	level_resource.condicion = Global.resolve_texture(
		run_data.get("condition_texture_path", "")
	)
	level_resource.ensenanza = Global.resolve_texture(
		run_data.get("teaching_texture_path", "")
	)
