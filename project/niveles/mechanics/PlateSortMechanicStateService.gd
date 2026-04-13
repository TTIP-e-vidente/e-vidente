extends RefCounted

const MAX_PLATE_COLUMNS := 3
const PLATE_ITEM_COLUMN_SPACING := 78.0
const PLATE_ITEM_ROW_SPACING := 48.0
const PLATE_ITEM_VERTICAL_OFFSET := -12.0

var _level_manager


func _init(level_manager) -> void:
	_level_manager = level_manager


func build_save_state(mechanic_type: String, current_run_index: int) -> Dictionary:
	var saved_items: Array = []
	var positive_item_ids_in_plate: Array = []
	for item in _level_manager.level_items:
		if not is_instance_valid(item):
			continue

		var item_path: String = str(item.item_resource_path).strip_edges()
		var instance_id: String = str(item.save_instance_id).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue

		saved_items.append(
			{
				Global.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
				Global.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
				Global.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(item.esPositivo)
			}
		)
		if item.esPositivo and _level_manager.plato.has_positive_item(item):
			positive_item_ids_in_plate.append(instance_id)

	if saved_items.is_empty() and current_run_index <= 1:
		return {}

	var saved_state: Dictionary = {
		Global.PARTIAL_LEVEL_ITEMS_KEY: saved_items,
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: positive_item_ids_in_plate
	}
	return {
		Global.PARTIAL_LEVEL_RUN_INDEX_KEY: current_run_index,
		Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		Global.PARTIAL_LEVEL_MECHANIC_STATE_KEY: saved_state,
		Global.PARTIAL_LEVEL_ITEMS_KEY: saved_items,
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: positive_item_ids_in_plate
	}


func build_save_summary(saved_level_state: Dictionary) -> Dictionary:
	var saved_state: Dictionary = _read_saved_state(saved_level_state)
	var raw_placed_item_ids: Variant = saved_state.get(
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


func restore_items(saved_level_state: Dictionary) -> bool:
	var saved_state: Dictionary = _read_saved_state(saved_level_state)
	var raw_items: Variant = saved_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	if not raw_items is Array or (raw_items as Array).is_empty():
		return false
	for saved_item in raw_items:
		if not _restore_item(saved_item):
			_level_manager.clear_runtime_items()
			return false
	return not _level_manager.level_items.is_empty()


func restore_items_in_plate(saved_level_state: Dictionary) -> void:
	var saved_state: Dictionary = _read_saved_state(saved_level_state)
	var raw_placed_item_ids: Variant = saved_state.get(
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	if not raw_placed_item_ids is Array or (raw_placed_item_ids as Array).is_empty():
		return

	var positive_items_in_plate: Array = []
	for raw_item_id in raw_placed_item_ids:
		var instance_id: String = str(raw_item_id).strip_edges()
		if instance_id.is_empty():
			continue
		var item = _find_item_by_instance_id(instance_id)
		if item == null or not item.esPositivo:
			continue
		positive_items_in_plate.append(item)

	for index in range(positive_items_in_plate.size()):
		var item = positive_items_in_plate[index]
		item.restore_to_plate(
			_get_plate_position(index, positive_items_in_plate.size())
		)
		_level_manager.plato.restore_positive_item(item)


func _read_saved_state(saved_level_state: Dictionary) -> Dictionary:
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


func _restore_item(raw_saved_item: Variant) -> bool:
	if not raw_saved_item is Dictionary:
		return false
	var saved_item: Dictionary = raw_saved_item
	var item_path: String = str(
		saved_item.get(Global.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		saved_item.get(Global.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false
	var level_item: LevelItem = load(item_path) as LevelItem
	if level_item == null:
		return false
	var is_positive: bool = bool(
		saved_item.get(Global.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
	)
	return _level_manager.spawn_level_item(level_item, instance_id, is_positive) != null


func _find_item_by_instance_id(instance_id: String):
	for item in _level_manager.level_items:
		if not is_instance_valid(item):
			continue
		if str(item.save_instance_id) == instance_id:
			return item
	return null


func _get_plate_position(index: int, total_items: int) -> Vector2:
	var columns: int = clampi(total_items, 1, MAX_PLATE_COLUMNS)
	var row: int = floori(float(index) / float(columns))
	var column: int = index % columns
	var horizontal_origin: float = float(columns - 1) / 2.0
	var offset: Vector2 = Vector2(
		(float(column) - horizontal_origin) * PLATE_ITEM_COLUMN_SPACING,
		float(row) * PLATE_ITEM_ROW_SPACING + PLATE_ITEM_VERTICAL_OFFSET
	)
	return _level_manager.plato.global_position + offset
