extends RefCounted

var _manager


func _init(manager) -> void:
	_manager = manager

func instantiate_level_item(level_item: LevelItem, instance_id: String, is_positive: bool):
	var new_item = level_item.escena.instantiate()
	if new_item == null:
		return null
	new_item.setup(level_item, _manager.plato, is_positive, instance_id)
	_manager.add_child(new_item)
	_manager.spawned_items.append(new_item)
	return new_item


func clear_spawned_items() -> void:
	for item in _manager.spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	_manager.spawned_items.clear()
	if not is_instance_valid(_manager.plato):
		return
	_manager.plato.elementos.clear()
	_manager.plato.cantAlimentosPos.clear()
	_manager.plato.cantAlimentosNeg.clear()
func layout_items(level_resource: LevelResource) -> void:
	var item_spawn_position := Vector2(230, 680)
	if (level_resource.cantidadNegativos + level_resource.cantidadPositivos) < 5:
		item_spawn_position = Vector2(420, 680)
	for item in _manager.spawned_items:
		item.set_home_position(item_spawn_position)
		item_spawn_position.x += 120