extends RefCounted

var _manager


func _init(manager) -> void:
	_manager = manager


func create_item(
	level_item: LevelItem,
	instance_id: String,
	is_positive: bool
):
	var level_item_instance = level_item.escena.instantiate()
	if level_item_instance == null:
		return null
	level_item_instance.setup(level_item, _manager.plato, is_positive, instance_id)
	_manager.add_child(level_item_instance)
	_manager.level_items.append(level_item_instance)
	return level_item_instance


func clear_items() -> void:
	for item in _manager.level_items:
		if is_instance_valid(item):
			item.queue_free()
	_manager.level_items.clear()
	if not is_instance_valid(_manager.plato):
		return
	_manager.plato.elementos.clear()
	_manager.plato.cantAlimentosPos.clear()
	_manager.plato.cantAlimentosNeg.clear()


func layout_items(level_resource: LevelResource) -> void:
	var next_item_position := Vector2(230, 680)
	var total_items: int = (
		level_resource.cantidadNegativos + level_resource.cantidadPositivos
	)
	if total_items < 5:
		next_item_position = Vector2(420, 680)

	for item in _manager.level_items:
		item.set_home_position(next_item_position)
		next_item_position.x += 120
