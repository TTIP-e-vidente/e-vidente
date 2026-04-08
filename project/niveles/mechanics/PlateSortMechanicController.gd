extends LevelMechanicController

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")


func get_mechanic_type() -> String:
	return LevelMechanicTypes.PLATE_SORT


func configure_run(run_data: Dictionary, level_resource: LevelResource) -> void:
	var payload: Dictionary = _resolve_payload(run_data)
	level_resource.mechanic_type = get_mechanic_type()
	level_resource.mechanic_payload = payload.duplicate(true)
	level_resource.cantidadNegativos = int(payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(payload.get("positive_count", 0))
	level_resource.comida = Global.resolve_texture(run_data.get("meal_texture_path", ""))
	level_resource.condicion = Global.resolve_texture(run_data.get("condition_texture_path", ""))
	level_resource.ensenanza = Global.resolve_texture(run_data.get("teaching_texture_path", ""))
	_manager.ensenanza.texture = level_resource.ensenanza
	_manager.meal.texture = level_resource.comida
	_manager.condition.texture = level_resource.condicion


func restore_or_start(saved_level_state: Dictionary) -> void:
	if not _spawn_items_from_saved_state(saved_level_state):
		_spawn_random_items()
		_manager.lista_items.shuffle()
	_manager._layout_items()
	_restore_saved_positive_items(saved_level_state)


func build_partial_state() -> Dictionary:
	var partial_state: Dictionary = {
		Global.PARTIAL_LEVEL_RUN_INDEX_KEY: _manager.get_current_run_index(),
		Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: get_mechanic_type()
	}
	var mechanic_state: Dictionary = _build_mechanic_state()
	if mechanic_state.is_empty() and _manager.get_current_run_index() <= 1:
		return {}
	partial_state[Global.PARTIAL_LEVEL_MECHANIC_STATE_KEY] = mechanic_state
	partial_state[Global.PARTIAL_LEVEL_ITEMS_KEY] = mechanic_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	partial_state[Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = mechanic_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	return partial_state


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	var mechanic_state: Dictionary = _extract_mechanic_state(partial_state)
	var raw_placed_item_ids: Variant = mechanic_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	var placed_item_count: int = raw_placed_item_ids.size() if raw_placed_item_ids is Array else 0
	return {
		"placed_positive_count": placed_item_count,
		"progress_count": placed_item_count,
		"progress_unit_singular": "alimento correcto en el plato",
		"progress_unit_plural": "alimentos correctos en el plato"
	}


func get_progress_count() -> int:
	return _manager.plato.cantAlimentosPos.keys().size()


func clear_runtime_state() -> void:
	_manager._clear_spawned_items()


func _resolve_payload(run_data: Dictionary) -> Dictionary:
	var raw_payload: Variant = run_data.get("mechanic_payload", {})
	if raw_payload is Dictionary and not raw_payload.is_empty():
		return (raw_payload as Dictionary).duplicate(true)
	return {
		"negative_count": int(run_data.get("negative_count", 0)),
		"positive_count": int(run_data.get("positive_count", 0)),
		"category": str(run_data.get("category", ""))
	}


func _spawn_random_items() -> void:
	var lista_negativos: Array = _manager.level_resource.itemsNegativos.duplicate()
	var lista_positivos: Array = _manager.level_resource.itemsPositivos.duplicate()
	lista_negativos.shuffle()
	lista_positivos.shuffle()
	var payload: Dictionary = _manager.level_resource.mechanic_payload if _manager.level_resource.mechanic_payload is Dictionary else {}
	var categoria_actual: String = str(payload.get("category", ""))
	var filtrados_positivos: Array = Global.item_categoria(lista_positivos, categoria_actual)
	var filtrados_negativos: Array = Global.item_categoria(lista_negativos, categoria_actual)
	for index in range(_manager.level_resource.cantidadPositivos):
		var raw_positive_item: Variant = filtrados_positivos.pop_front()
		var positive_item: LevelItem = raw_positive_item as LevelItem
		if positive_item == null:
			continue
		_manager._instantiate_level_item(positive_item, "positive_%d" % index, true)
	for index in range(_manager.level_resource.cantidadNegativos):
		var raw_negative_item: Variant = filtrados_negativos.pop_front()
		var negative_item: LevelItem = raw_negative_item as LevelItem
		if negative_item == null:
			continue
		_manager._instantiate_level_item(negative_item, "negative_%d" % index, false)


func _build_mechanic_state() -> Dictionary:
	var items: Array = []
	var placed_item_ids: Array = []
	for item in _manager.lista_items:
		if not is_instance_valid(item):
			continue
		var item_path: String = str(item.item_resource_path).strip_edges()
		var instance_id: String = str(item.save_instance_id).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue
		items.append({
			Global.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
			Global.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
			Global.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(item.esPositivo)
		})
		if item.esPositivo and _manager.plato.has_positive_item(item):
			placed_item_ids.append(instance_id)
	return {
		Global.PARTIAL_LEVEL_ITEMS_KEY: items,
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_item_ids
	}


func _spawn_items_from_saved_state(saved_level_state: Dictionary) -> bool:
	var mechanic_state: Dictionary = _extract_mechanic_state(saved_level_state)
	var raw_items: Variant = mechanic_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	if not raw_items is Array or raw_items.is_empty():
		return false
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			_manager._clear_spawned_items()
			return false
		var item_path: String = str(raw_item.get(Global.PARTIAL_LEVEL_ITEM_PATH_KEY, "")).strip_edges()
		var instance_id: String = str(raw_item.get(Global.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")).strip_edges()
		var is_positive: bool = bool(raw_item.get(Global.PARTIAL_LEVEL_IS_POSITIVE_KEY, false))
		var level_item: LevelItem = load(item_path) as LevelItem
		if level_item == null or instance_id.is_empty():
			_manager._clear_spawned_items()
			return false
		if _manager._instantiate_level_item(level_item, instance_id, is_positive) == null:
			_manager._clear_spawned_items()
			return false
	return not _manager.lista_items.is_empty()


func _restore_saved_positive_items(saved_level_state: Dictionary) -> void:
	var mechanic_state: Dictionary = _extract_mechanic_state(saved_level_state)
	var raw_placed_item_ids: Variant = mechanic_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	if not raw_placed_item_ids is Array or raw_placed_item_ids.is_empty():
		return
	var items_in_plate: Array = []
	for raw_item_id in raw_placed_item_ids:
		var item = _find_item_by_instance_id(str(raw_item_id).strip_edges())
		if item == null or not item.esPositivo:
			continue
		items_in_plate.append(item)
	for index in range(items_in_plate.size()):
		var item = items_in_plate[index]
		item.restore_to_plate(_plate_position_for_index(index, items_in_plate.size()))
		_manager.plato.restore_positive_item(item)


func _extract_mechanic_state(saved_level_state: Dictionary) -> Dictionary:
	var raw_mechanic_state: Variant = saved_level_state.get(Global.PARTIAL_LEVEL_MECHANIC_STATE_KEY, {})
	if raw_mechanic_state is Dictionary:
		return raw_mechanic_state
	return {
		Global.PARTIAL_LEVEL_ITEMS_KEY: saved_level_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, []),
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: saved_level_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	}


func _find_item_by_instance_id(instance_id: String):
	for item in _manager.lista_items:
		if not is_instance_valid(item):
			continue
		if str(item.save_instance_id) == instance_id:
			return item
	return null


func _plate_position_for_index(index: int, total_items: int) -> Vector2:
	var columns: int = total_items
	if columns < 1:
		columns = 1
	elif columns > 3:
		columns = 3
	var row: int = floori(float(index) / float(columns))
	var column: int = index % columns
	var horizontal_origin: float = float(columns - 1) / 2.0
	var offset := Vector2((float(column) - horizontal_origin) * 78.0, float(row) * 48.0 - 12.0)
	return _manager.plato.global_position + offset
