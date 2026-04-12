extends RefCounted

const MAX_PLATE_COLUMNS := 3
const PLATE_ITEM_COLUMN_SPACING := 78.0
const PLATE_ITEM_ROW_SPACING := 48.0
const PLATE_ITEM_VERTICAL_OFFSET := -12.0

var _level_manager


func _init(level_manager) -> void:
	_level_manager = level_manager


func build_partial_state(mechanic_type: String, current_run_index: int) -> Dictionary:
	var plate_sort_state: Dictionary = _build_current_plate_sort_state()
	var item_snapshots: Array = _get_saved_item_snapshots(plate_sort_state)
	if item_snapshots.is_empty() and current_run_index <= 1:
		return {}
	var placed_positive_item_ids: Array = _get_placed_positive_item_ids(plate_sort_state)
	return {
		Global.PARTIAL_LEVEL_RUN_INDEX_KEY: current_run_index,
		Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		Global.PARTIAL_LEVEL_MECHANIC_STATE_KEY: plate_sort_state,
		Global.PARTIAL_LEVEL_ITEMS_KEY: item_snapshots,
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	var plate_sort_state: Dictionary = _extract_plate_sort_state(partial_state)
	var placed_item_count: int = _get_placed_positive_item_ids(plate_sort_state).size()
	return {
		"placed_positive_count": placed_item_count,
		"progress_count": placed_item_count,
		"progress_unit_singular": "alimento correcto en el plato",
		"progress_unit_plural": "alimentos correctos en el plato"
	}


func spawn_items_from_saved_state(saved_level_state: Dictionary) -> bool:
	var plate_sort_state: Dictionary = _extract_plate_sort_state(saved_level_state)
	var saved_item_snapshots: Array = _get_saved_item_snapshots(plate_sort_state)
	if saved_item_snapshots.is_empty():
		return false
	for item_snapshot in saved_item_snapshots:
		if not _spawn_runtime_item_from_snapshot(item_snapshot):
			_level_manager.clear_runtime_items()
			return false
	return not _level_manager.level_items.is_empty()


func restore_saved_positive_items(saved_level_state: Dictionary) -> void:
	var plate_sort_state: Dictionary = _extract_plate_sort_state(saved_level_state)
	var placed_positive_item_ids: Array = _get_placed_positive_item_ids(plate_sort_state)
	if placed_positive_item_ids.is_empty():
		return
	var positive_items_in_plate: Array = _find_positive_items_for_plate(
		placed_positive_item_ids
	)
	_restore_positive_items_to_plate(positive_items_in_plate)


func _extract_plate_sort_state(saved_level_state: Dictionary) -> Dictionary:
	var raw_mechanic_state: Variant = saved_level_state.get(
		Global.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return _build_legacy_plate_sort_state(saved_level_state)


func _build_legacy_plate_sort_state(saved_level_state: Dictionary) -> Dictionary:
	return {
		Global.PARTIAL_LEVEL_ITEMS_KEY: saved_level_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, []),
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: saved_level_state.get(
			Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _get_saved_item_snapshots(plate_sort_state: Dictionary) -> Array:
	var raw_items: Variant = plate_sort_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	return (raw_items as Array).duplicate(true) if raw_items is Array else []


func _get_placed_positive_item_ids(plate_sort_state: Dictionary) -> Array:
	var raw_placed_item_ids: Variant = plate_sort_state.get(
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	return (raw_placed_item_ids as Array).duplicate(true) if raw_placed_item_ids is Array else []


func _spawn_runtime_item_from_snapshot(item_snapshot: Variant) -> bool:
	if not item_snapshot is Dictionary:
		return false
	var saved_item_snapshot: Dictionary = item_snapshot
	var item_path: String = str(
		saved_item_snapshot.get(Global.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		saved_item_snapshot.get(Global.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false
	var level_item: LevelItem = load(item_path) as LevelItem
	if level_item == null:
		return false
	var is_positive: bool = bool(
		saved_item_snapshot.get(Global.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
	)
	return _level_manager.spawn_level_item(level_item, instance_id, is_positive) != null


func _build_current_plate_sort_state() -> Dictionary:
	var items: Array = []
	var placed_positive_item_ids: Array = []
	for item in _level_manager.level_items:
		var item_snapshot: Dictionary = _build_runtime_item_snapshot(item)
		if item_snapshot.is_empty():
			continue
		items.append(item_snapshot)
		if item.esPositivo and _level_manager.plato.has_positive_item(item):
			placed_positive_item_ids.append(
				str(item_snapshot.get(Global.PARTIAL_LEVEL_INSTANCE_ID_KEY, ""))
			)
	return {
		Global.PARTIAL_LEVEL_ITEMS_KEY: items,
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}


func _build_runtime_item_snapshot(item: Variant) -> Dictionary:
	if not is_instance_valid(item):
		return {}
	var item_path: String = str(item.item_resource_path).strip_edges()
	var instance_id: String = str(item.save_instance_id).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return {}
	return {
		Global.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
		Global.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
		Global.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(item.esPositivo)
	}


func _find_positive_items_for_plate(placed_positive_item_ids: Array) -> Array:
	var positive_items_in_plate: Array = []
	for raw_item_id in placed_positive_item_ids:
		var item = _find_runtime_item_by_instance_id(str(raw_item_id).strip_edges())
		if item == null or not item.esPositivo:
			continue
		positive_items_in_plate.append(item)
	return positive_items_in_plate


func _restore_positive_items_to_plate(positive_items_in_plate: Array) -> void:
	for index in range(positive_items_in_plate.size()):
		var item = positive_items_in_plate[index]
		item.restore_to_plate(
			_plate_position_for_index(index, positive_items_in_plate.size())
		)
		_level_manager.plato.restore_positive_item(item)


func _find_runtime_item_by_instance_id(instance_id: String):
	for item in _level_manager.level_items:
		if not is_instance_valid(item):
			continue
		if str(item.save_instance_id) == instance_id:
			return item
	return null


func _plate_position_for_index(index: int, total_items: int) -> Vector2:
	var columns: int = clampi(total_items, 1, MAX_PLATE_COLUMNS)
	var row: int = floori(float(index) / float(columns))
	var column: int = index % columns
	var horizontal_origin: float = float(columns - 1) / 2.0
	var offset: Vector2 = Vector2(
		(float(column) - horizontal_origin) * PLATE_ITEM_COLUMN_SPACING,
		float(row) * PLATE_ITEM_ROW_SPACING + PLATE_ITEM_VERTICAL_OFFSET
	)
	return _level_manager.plato.global_position + offset
