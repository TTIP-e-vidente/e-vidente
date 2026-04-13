extends "res://niveles/mechanics/LevelMechanicController.gd"

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const PlateSortMechanicStateServiceScript := preload(
	"res://niveles/mechanics/PlateSortMechanicStateService.gd"
)

var _plate_sort_state_service


func _init(level_manager) -> void:
	super(level_manager)
	_plate_sort_state_service = PlateSortMechanicStateServiceScript.new(level_manager)


func get_mechanic_type() -> String:
	return LevelMechanicTypes.PLATE_SORT


func configure_run(run_data: Dictionary, level_resource) -> void:
	var raw_payload: Variant = run_data.get("mechanic_payload", {})
	var run_payload: Dictionary = {}

	if raw_payload is Dictionary and not (raw_payload as Dictionary).is_empty():
		run_payload = (raw_payload as Dictionary).duplicate(true)
	else:
		run_payload = {
			"negative_count": int(run_data.get("negative_count", 0)),
			"positive_count": int(run_data.get("positive_count", 0)),
			"category": str(run_data.get("category", ""))
		}

	level_resource.mechanic_type = get_mechanic_type()
	level_resource.mechanic_payload = run_payload.duplicate(true)
	level_resource.cantidadNegativos = int(run_payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(run_payload.get("positive_count", 0))


func restore_or_start(saved_level_state: Dictionary) -> void:
	var restored_saved_items: bool = _plate_sort_state_service.restore_items(
		saved_level_state
	)
	if not restored_saved_items:
		_spawn_runtime_items_for_current_run()
		_level_manager.level_items.shuffle()

	_level_manager.layout_runtime_items()
	_plate_sort_state_service.restore_items_in_plate(saved_level_state)


func build_partial_state() -> Dictionary:
	return _plate_sort_state_service.build_save_state(
		get_mechanic_type(),
		_level_manager.get_current_run_index()
	)


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	return _plate_sort_state_service.build_save_summary(partial_state)


func get_progress_count() -> int:
	return _level_manager.plato.cantAlimentosPos.size()


func clear_runtime_state() -> void:
	_level_manager.clear_runtime_items()

func _spawn_runtime_items_for_current_run() -> void:
	var level_resource = _level_manager.level_resource
	var track_key: String = _level_manager.active_track_key
	var raw_payload: Variant = level_resource.mechanic_payload
	var payload: Dictionary = raw_payload if raw_payload is Dictionary else {}
	var category_code: String = str(payload.get("category", ""))

	var positive_items: Array = _level_manager.filter_items_by_category(
		level_resource.get_positive_items(track_key),
		category_code
	)
	positive_items.shuffle()
	_spawn_items_from_pool(
		positive_items,
		level_resource.cantidadPositivos,
		"positive",
		true
	)

	var negative_items: Array = _level_manager.filter_items_by_category(
		level_resource.get_negative_items(track_key),
		category_code
	)
	negative_items.shuffle()
	_spawn_items_from_pool(
		negative_items,
		level_resource.cantidadNegativos,
		"negative",
		false
	)


func _spawn_items_from_pool(
	item_pool: Array,
	wanted_count: int,
	instance_prefix: String,
	is_positive: bool
) -> void:
	for item_index in range(wanted_count):
		if item_pool.is_empty():
			break
		var level_item = item_pool.pop_front()
		if level_item == null:
			continue
		_level_manager.spawn_level_item(
			level_item,
			"%s_%d" % [instance_prefix, item_index],
			is_positive
		)
