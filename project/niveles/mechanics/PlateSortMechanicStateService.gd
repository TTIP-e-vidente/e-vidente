extends RefCounted

const GlobalStateScript := preload("res://niveles/global.gd")

const MAX_PLATE_COLUMNS := 3
const PLATE_ITEM_COLUMN_SPACING := 78.0
const PLATE_ITEM_ROW_SPACING := 48.0
const PLATE_ITEM_VERTICAL_OFFSET := -12.0

var _level_manager


func _init(level_manager) -> void:
	_level_manager = level_manager


func build_save_state(mechanic_type: String, current_run_index: int) -> Dictionary:
	var saved_items: Array = []
	var placed_positive_item_ids: Array = []

	for runtime_item in _level_manager.level_items:
		if not is_instance_valid(runtime_item):
			continue

		var item_path: String = str(runtime_item.item_resource_path).strip_edges()
		var instance_id: String = str(runtime_item.save_instance_id).strip_edges()
		var is_positive: bool = bool(runtime_item.esPositivo)
		if item_path.is_empty() or instance_id.is_empty():
			continue

		saved_items.append(
			{
				GlobalStateScript.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
				GlobalStateScript.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
				GlobalStateScript.PARTIAL_LEVEL_IS_POSITIVE_KEY: is_positive
			}
		)
		if is_positive and _level_manager.plato.has_positive_item(runtime_item):
			placed_positive_item_ids.append(instance_id)

	if saved_items.is_empty() and current_run_index <= 1:
		return {}

	var mechanic_state: Dictionary = {
		GlobalStateScript.PARTIAL_LEVEL_ITEMS_KEY: saved_items,
		GlobalStateScript.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}

	return {
		GlobalStateScript.PARTIAL_LEVEL_RUN_INDEX_KEY: current_run_index,
		GlobalStateScript.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		GlobalStateScript.PARTIAL_LEVEL_MECHANIC_STATE_KEY: mechanic_state,
		GlobalStateScript.PARTIAL_LEVEL_ITEMS_KEY: saved_items,
		GlobalStateScript.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}


func build_save_summary(saved_level_state: Dictionary) -> Dictionary:
	var plate_sort_state: Dictionary = _read_plate_sort_state(saved_level_state)
	var raw_placed_positive_item_ids: Variant = plate_sort_state.get(
		GlobalStateScript.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	var placed_item_count: int = (
		raw_placed_positive_item_ids.size()
		if raw_placed_positive_item_ids is Array
		else 0
	)
	return {
		"placed_positive_count": placed_item_count,
		"progress_count": placed_item_count,
		"progress_unit_singular": "alimento correcto en el plato",
		"progress_unit_plural": "alimentos correctos en el plato"
	}


func restore_items(saved_level_state: Dictionary) -> bool:
	var plate_sort_state: Dictionary = _read_plate_sort_state(saved_level_state)
	var raw_saved_items: Variant = plate_sort_state.get(
		GlobalStateScript.PARTIAL_LEVEL_ITEMS_KEY,
		[]
	)
	if not raw_saved_items is Array or (raw_saved_items as Array).is_empty():
		return false

	for raw_saved_item in raw_saved_items:
		if not _restore_saved_item(raw_saved_item):
			_level_manager.clear_runtime_items()
			return false

	return not _level_manager.level_items.is_empty()


func restore_items_in_plate(saved_level_state: Dictionary) -> void:
	var plate_sort_state: Dictionary = _read_plate_sort_state(saved_level_state)
	var raw_placed_positive_item_ids: Variant = plate_sort_state.get(
		GlobalStateScript.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	if (
		not raw_placed_positive_item_ids is Array
		or (raw_placed_positive_item_ids as Array).is_empty()
	):
		return

	var placed_positive_items: Array = []
	for raw_item_id in raw_placed_positive_item_ids:
		var instance_id: String = str(raw_item_id).strip_edges()
		if instance_id.is_empty():
			continue
		var runtime_item = _find_runtime_item_by_instance_id(instance_id)
		if runtime_item == null or not runtime_item.esPositivo:
			continue
		placed_positive_items.append(runtime_item)

	for item_index in range(placed_positive_items.size()):
		var runtime_item = placed_positive_items[item_index]
		runtime_item.restore_to_plate(
			_get_plate_position(item_index, placed_positive_items.size())
		)
		_level_manager.plato.restore_positive_item(runtime_item)


func _read_plate_sort_state(saved_level_state: Dictionary) -> Dictionary:
	# Save actual: el estado vive dentro de mechanic_state.
	# Compatibilidad legacy: items y placed IDs podían vivir en la raíz.
	var raw_mechanic_state: Variant = saved_level_state.get(
		GlobalStateScript.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return {
		GlobalStateScript.PARTIAL_LEVEL_ITEMS_KEY: saved_level_state.get(
			GlobalStateScript.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		),
		GlobalStateScript.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: saved_level_state.get(
			GlobalStateScript.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _restore_saved_item(raw_saved_item: Variant) -> bool:
	if not raw_saved_item is Dictionary:
		return false
	var saved_item: Dictionary = raw_saved_item
	var item_path: String = str(
		saved_item.get(GlobalStateScript.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		saved_item.get(GlobalStateScript.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false
	var level_item: LevelItem = load(item_path) as LevelItem
	if level_item == null:
		return false
	var is_positive: bool = bool(
		saved_item.get(GlobalStateScript.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
	)
	return _level_manager.spawn_level_item(level_item, instance_id, is_positive) != null


func _find_runtime_item_by_instance_id(instance_id: String):
	for runtime_item in _level_manager.level_items:
		if not is_instance_valid(runtime_item):
			continue
		if str(runtime_item.save_instance_id) == instance_id:
			return runtime_item
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
