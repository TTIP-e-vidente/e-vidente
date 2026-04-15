extends RefCounted

const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")

const MAX_PLATE_COLUMNS := 3
const PLATE_ITEM_COLUMN_SPACING := 78.0
const PLATE_ITEM_ROW_SPACING := 48.0
const PLATE_ITEM_VERTICAL_OFFSET := -12.0

var _level_manager


func _init(level_manager) -> void:
	_level_manager = level_manager


func build_save_state(mechanic_type: String, saved_run_index: int) -> Dictionary:
	var runtime_snapshot: Dictionary = _build_runtime_snapshot()
	var saved_items: Array = runtime_snapshot.get("saved_items", [])
	var placed_positive_item_ids: Array = runtime_snapshot.get(
		"placed_positive_item_ids",
		[]
	)

	if saved_items.is_empty() and saved_run_index <= 1:
		return {}

	var mechanic_state: Dictionary = _build_plate_sort_mechanic_state(
		saved_items,
		placed_positive_item_ids
	)
	return {
		GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY: saved_run_index,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: mechanic_type,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY: mechanic_state,
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: saved_items,
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}


func build_save_summary(saved_level_state: Dictionary) -> Dictionary:
	var placed_positive_item_ids: Array = _read_saved_positive_item_ids(saved_level_state)
	var placed_item_count: int = placed_positive_item_ids.size()
	return {
		"placed_positive_count": placed_item_count,
		"progress_count": placed_item_count,
		"progress_unit_singular": "alimento correcto en el plato",
		"progress_unit_plural": "alimentos correctos en el plato"
	}


func restore_items(saved_level_state: Dictionary) -> bool:
	var saved_items: Array = _read_saved_item_entries(saved_level_state)
	if saved_items.is_empty():
		return false

	for raw_saved_item in saved_items:
		if not _restore_saved_item(raw_saved_item):
			_level_manager.clear_runtime_items()
			return false

	return not _level_manager.level_items.is_empty()


func restore_items_in_plate(saved_level_state: Dictionary) -> void:
	var saved_positive_item_ids: Array = _read_saved_positive_item_ids(saved_level_state)
	if saved_positive_item_ids.is_empty():
		return

	var runtime_items_to_restore: Array = _collect_runtime_positive_items_to_restore(
		saved_positive_item_ids
	)

	for item_index in range(runtime_items_to_restore.size()):
		var runtime_item = runtime_items_to_restore[item_index]
		_restore_runtime_item_to_plate(
			runtime_item,
			item_index,
			runtime_items_to_restore.size()
		)


func _build_runtime_snapshot() -> Dictionary:
	var saved_items: Array = []
	var placed_positive_item_ids: Array = []

	for runtime_item in _level_manager.level_items:
		if not is_instance_valid(runtime_item):
			continue

		var saved_item_entry: Dictionary = _build_saved_item_entry(runtime_item)
		if saved_item_entry.is_empty():
			continue

		saved_items.append(saved_item_entry)
		if bool(runtime_item.esPositivo) and _level_manager.plato.has_positive_item(runtime_item):
			placed_positive_item_ids.append(
				str(
					saved_item_entry.get(
						GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY,
						""
					)
				)
			)

	return {
		"saved_items": saved_items,
		"placed_positive_item_ids": placed_positive_item_ids
	}


func _build_saved_item_entry(runtime_item) -> Dictionary:
	var item_path: String = str(runtime_item.item_resource_path).strip_edges()
	var instance_id: String = str(runtime_item.save_instance_id).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return {}

	return {
		GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
		GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
		GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(runtime_item.esPositivo)
	}


func _build_plate_sort_mechanic_state(
	saved_items: Array,
	placed_positive_item_ids: Array
) -> Dictionary:
	return {
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: saved_items,
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}


func _read_saved_item_entries(saved_level_state: Dictionary) -> Array:
	return _read_plate_sort_state_array(
		saved_level_state,
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY
	)


func _read_saved_positive_item_ids(saved_level_state: Dictionary) -> Array:
	return _read_plate_sort_state_array(
		saved_level_state,
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY
	)


func _read_plate_sort_state_array(
	saved_level_state: Dictionary,
	state_key: String
) -> Array:
	var plate_sort_state: Dictionary = _read_plate_sort_state(saved_level_state)
	var raw_state_value: Variant = plate_sort_state.get(state_key, [])
	return raw_state_value if raw_state_value is Array else []


func _collect_runtime_positive_items_to_restore(saved_positive_item_ids: Array) -> Array:
	var runtime_items_to_restore: Array = []

	for raw_item_id in saved_positive_item_ids:
		var instance_id: String = str(raw_item_id).strip_edges()
		if instance_id.is_empty():
			continue

		var runtime_item = _find_runtime_item_by_instance_id(instance_id)
		if runtime_item == null or not runtime_item.esPositivo:
			continue

		runtime_items_to_restore.append(runtime_item)

	return runtime_items_to_restore


func _restore_runtime_item_to_plate(runtime_item, item_index: int, total_items: int) -> void:
	runtime_item.restore_to_plate(_get_plate_position(item_index, total_items))
	_level_manager.plato.restore_positive_item(runtime_item)


func _read_plate_sort_state(saved_level_state: Dictionary) -> Dictionary:
	var raw_mechanic_state: Variant = saved_level_state.get(
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return {
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: saved_level_state.get(
			GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		),
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: saved_level_state.get(
			GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _restore_saved_item(raw_saved_item: Variant) -> bool:
	if not raw_saved_item is Dictionary:
		return false
	var saved_item: Dictionary = raw_saved_item
	var item_path: String = str(
		saved_item.get(GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		saved_item.get(GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false
	var level_item = load(item_path)
	if level_item == null:
		return false
	var is_positive: bool = bool(
		saved_item.get(GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
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
