extends LevelMechanicController

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const PlateSortMechanicStateServiceScript := preload(
	"res://niveles/mechanics/PlateSortMechanicStateService.gd"
)

var _save_service


func _init(level_manager) -> void:
	super(level_manager)
	_save_service = PlateSortMechanicStateServiceScript.new(level_manager)


func get_mechanic_type() -> String:
	return LevelMechanicTypes.PLATE_SORT


func configure_run(run_data: Dictionary, level_resource: LevelResource) -> void:
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
	var restored_saved_items: bool = _save_service.restore_items(saved_level_state)
	if not restored_saved_items:
		_spawn_items_for_run()
		_level_manager.level_items.shuffle()

	_level_manager.layout_runtime_items()
	_save_service.restore_items_in_plate(saved_level_state)


func build_partial_state() -> Dictionary:
	return _save_service.build_save_state(
		get_mechanic_type(),
		_level_manager.get_current_run_index()
	)


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	return _save_service.build_save_summary(partial_state)


func get_progress_count() -> int:
	return _level_manager.plato.cantAlimentosPos.keys().size()


func clear_runtime_state() -> void:
	_level_manager.clear_runtime_items()


func _spawn_items_for_run() -> void:
	var run_payload: Dictionary = (
		_level_manager.level_resource.mechanic_payload
		if _level_manager.level_resource.mechanic_payload is Dictionary
		else {}
	)
	var category_code: String = str(run_payload.get("category", ""))

	var positive_items: Array = _level_manager.level_resource.get_positive_items(
		_level_manager.active_track_key
	)
	positive_items = _level_manager.filter_items_by_category(positive_items, category_code)
	positive_items.shuffle()
	for item_index in range(_level_manager.level_resource.cantidadPositivos):
		if positive_items.is_empty():
			break
		var positive_item: LevelItem = positive_items.pop_front() as LevelItem
		if positive_item == null:
			continue
		_level_manager.spawn_level_item(
			positive_item,
			"positive_%d" % item_index,
			true
		)

	var negative_items: Array = _level_manager.level_resource.get_negative_items(
		_level_manager.active_track_key
	)
	negative_items = _level_manager.filter_items_by_category(negative_items, category_code)
	negative_items.shuffle()
	for item_index in range(_level_manager.level_resource.cantidadNegativos):
		if negative_items.is_empty():
			break
		var negative_item: LevelItem = negative_items.pop_front() as LevelItem
		if negative_item == null:
			continue
		_level_manager.spawn_level_item(
			negative_item,
			"negative_%d" % item_index,
			false
		)
