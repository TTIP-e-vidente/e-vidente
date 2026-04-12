extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func build_partial_state(mechanic_type: String, current_run_index: int) -> Dictionary:
	var partial_state: Dictionary = {
		Global.PARTIAL_LEVEL_RUN_INDEX_KEY: current_run_index,
		Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type
	}
	var mechanic_state: Dictionary = _build_mechanic_state()
	var raw_items: Variant = mechanic_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	var items: Array = raw_items if raw_items is Array else []
	if items.is_empty() and current_run_index <= 1:
		return {}
	var raw_placed_item_ids: Variant = mechanic_state.get(
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	var placed_item_ids: Array = raw_placed_item_ids if raw_placed_item_ids is Array else []
	partial_state[Global.PARTIAL_LEVEL_MECHANIC_STATE_KEY] = mechanic_state
	partial_state[Global.PARTIAL_LEVEL_ITEMS_KEY] = items.duplicate(true)
	partial_state[Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = placed_item_ids.duplicate(true)
	return partial_state


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	var mechanic_state: Dictionary = extract_mechanic_state(partial_state)
	var raw_placed_item_ids: Variant = mechanic_state.get(
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	var placed_item_count: int = raw_placed_item_ids.size() if raw_placed_item_ids is Array else 0
	return {
		"placed_positive_count": placed_item_count,
		"progress_count": placed_item_count,
		"progress_unit_singular": "alimento correcto en el plato",
		"progress_unit_plural": "alimentos correctos en el plato"
	}


func spawn_items_from_saved_state(saved_level_state: Dictionary) -> bool:
	var saved_runtime_items: Array = _extract_saved_runtime_items(saved_level_state)
	if saved_runtime_items.is_empty():
		return false
	for saved_runtime_item in saved_runtime_items:
		if _spawn_saved_runtime_item(saved_runtime_item):
			continue
		_manager.clear_runtime_items()
		return false
	return not _manager.level_items.is_empty()


func restore_saved_positive_items(saved_level_state: Dictionary) -> void:
	var mechanic_state: Dictionary = extract_mechanic_state(saved_level_state)
	var raw_placed_item_ids: Variant = mechanic_state.get(
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
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


func extract_mechanic_state(saved_level_state: Dictionary) -> Dictionary:
	var raw_mechanic_state: Variant = saved_level_state.get(
		Global.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return {
		Global.PARTIAL_LEVEL_ITEMS_KEY: saved_level_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, []),
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: saved_level_state.get(
			Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _extract_saved_runtime_items(saved_level_state: Dictionary) -> Array:
	var mechanic_state: Dictionary = extract_mechanic_state(saved_level_state)
	var raw_items: Variant = mechanic_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	return raw_items if raw_items is Array else []


func _spawn_saved_runtime_item(saved_runtime_item: Variant) -> bool:
	if not saved_runtime_item is Dictionary:
		return false
	var item_snapshot: Dictionary = saved_runtime_item
	var item_path: String = str(
		item_snapshot.get(Global.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		item_snapshot.get(Global.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false
	var level_item: LevelItem = load(item_path) as LevelItem
	if level_item == null:
		return false
	var is_positive: bool = bool(item_snapshot.get(Global.PARTIAL_LEVEL_IS_POSITIVE_KEY, false))
	return _manager.spawn_level_item(level_item, instance_id, is_positive) != null


func _build_mechanic_state() -> Dictionary:
	var items: Array = []
	var placed_item_ids: Array = []
	for item in _manager.level_items:
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


func _find_item_by_instance_id(instance_id: String):
	for item in _manager.level_items:
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
	var offset: Vector2 = Vector2(
		(float(column) - horizontal_origin) * 78.0,
		float(row) * 48.0 - 12.0
	)
	return _manager.plato.global_position + offset
