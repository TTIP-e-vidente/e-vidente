extends RefCounted

var _manager


func _init(manager) -> void:
	_manager = manager

func ensure_level_references() -> bool:
	var level_root: Node = _manager.get_parent()
	if level_root == null:
		push_error("ManagerLevel no encontro la escena de nivel contenedora.")
		return false
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
	if (
		not is_instance_valid(_manager.plato)
		or not is_instance_valid(_manager.meal_sprite)
		or not is_instance_valid(_manager.condition_sprite)
		or not is_instance_valid(_manager.teaching_sprite)
	):
		push_error(
			"ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual."
		)
		return false
	return true
func apply_run_visuals(level_resource: LevelResource, run_data: Dictionary) -> void:
	level_resource.comida = Global.resolve_texture(run_data.get("meal_texture_path", ""))
	level_resource.condicion = Global.resolve_texture(
		run_data.get("condition_texture_path", "")
	)
	level_resource.ensenanza = Global.resolve_texture(
		run_data.get("teaching_texture_path", "")
	)
	_manager.meal_sprite.texture = level_resource.comida
	_manager.condition_sprite.texture = level_resource.condicion
	_manager.teaching_sprite.texture = level_resource.ensenanza