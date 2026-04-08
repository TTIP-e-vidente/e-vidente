extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func build_partial_save_state() -> Dictionary:
	var partial_state := {Global.PARTIAL_LEVEL_RUN_INDEX_KEY: _manager.get_current_run_index()}
	var items: Array = []
	var placed_item_ids: Array = []
	for item in _manager.lista_items:
		if not is_instance_valid(item):
			continue
		var item_path := str(item.item_resource_path).strip_edges()
		var instance_id := str(item.save_instance_id).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue
		items.append({
			_manager.PARTIAL_ITEM_PATH_KEY: item_path,
			_manager.PARTIAL_INSTANCE_ID_KEY: instance_id,
			_manager.PARTIAL_IS_POSITIVE_KEY: bool(item.esPositivo)
		})
		if item.esPositivo and _manager.plato.has_positive_item(item):
			placed_item_ids.append(instance_id)
	if items.is_empty() and int(partial_state.get(Global.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)) <= 1:
		return {}
	partial_state[Global.PARTIAL_LEVEL_ITEMS_KEY] = items
	partial_state[Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY] = placed_item_ids
	return partial_state


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_state := build_partial_save_state()
	Global.set_partial_level_state(track_key, Global.current_level, partial_state)
	var placed_item_ids = partial_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	return {
		"placed_positive_count": placed_item_ids.size() if placed_item_ids is Array else 0,
		"has_partial_state": not partial_state.is_empty(),
		"run_index": _manager.get_current_run_index(),
		"run_count": _manager.get_total_runs()
	}


func spawn_items_from_saved_state(saved_level_state: Dictionary) -> bool:
	var raw_items = saved_level_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	if not raw_items is Array or raw_items.is_empty():
		return false
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			_manager._clear_spawned_items()
			return false
		var item_path := str(raw_item.get(_manager.PARTIAL_ITEM_PATH_KEY, "")).strip_edges()
		var instance_id := str(raw_item.get(_manager.PARTIAL_INSTANCE_ID_KEY, "")).strip_edges()
		var is_positive := bool(raw_item.get(_manager.PARTIAL_IS_POSITIVE_KEY, false))
		var level_item := load(item_path) as LevelItem
		if level_item == null or instance_id.is_empty():
			_manager._clear_spawned_items()
			return false
		if _manager._instantiate_level_item(level_item, instance_id, is_positive) == null:
			_manager._clear_spawned_items()
			return false
	return not _manager.lista_items.is_empty()


func restore_saved_positive_items(saved_level_state: Dictionary) -> void:
	var raw_placed_item_ids = saved_level_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	if not raw_placed_item_ids is Array or raw_placed_item_ids.is_empty():
		return
	var items_in_plate: Array = []
	for raw_item_id in raw_placed_item_ids:
		var item = find_item_by_instance_id(str(raw_item_id).strip_edges())
		if item == null or not item.esPositivo:
			continue
		items_in_plate.append(item)
	for index in range(items_in_plate.size()):
		var item = items_in_plate[index]
		item.restore_to_plate(_plate_position_for_index(index, items_in_plate.size()))
		_manager.plato.restore_positive_item(item)


func find_item_by_instance_id(instance_id: String):
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
	var horizontal_origin := float(columns - 1) / 2.0
	var offset := Vector2((float(column) - horizontal_origin) * 78.0, float(row) * 48.0 - 12.0)
	return _manager.plato.global_position + offset