extends LevelMechanicController
## Controller de la mecanica plate sort.
##
## Prepara la corrida actual y decide si debe restaurar el runtime desde un
## save parcial o generar los items nuevos para la corrida.

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


func configure_run(run_data: Dictionary, level_resource: LevelResource) -> void:
	var run_payload := _extract_run_payload(run_data)

	level_resource.mechanic_type = get_mechanic_type()
	level_resource.mechanic_payload = run_payload.duplicate(true)
	level_resource.cantidadNegativos = int(run_payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(run_payload.get("positive_count", 0))


func restore_or_start(saved_level_state: Dictionary) -> void:
	var restored_saved_items: bool = _plate_sort_state_service.restore_items(saved_level_state)
	if not restored_saved_items:
		_spawn_items_for_run()
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
	return _level_manager.plato.cantAlimentosPos.keys().size()


func clear_runtime_state() -> void:
	_level_manager.clear_runtime_items()


func _extract_run_payload(run_data: Dictionary) -> Dictionary:
	var nested: Variant = run_data.get("mechanic_payload", {})
	if nested is Dictionary and not (nested as Dictionary).is_empty():
		return (nested as Dictionary).duplicate(true)

	return {
		"negative_count": int(run_data.get("negative_count", 0)),
		"positive_count": int(run_data.get("positive_count", 0)),
		"category": str(run_data.get("category", ""))
	}


func _spawn_items_for_run() -> void:
	var level_resource := _level_manager.level_resource
	var track_key: String = _level_manager.active_track_key
	var raw_payload = level_resource.mechanic_payload
	var payload: Dictionary = raw_payload if raw_payload is Dictionary else {}
	var category_code: String = str(payload.get("category", ""))

	var positive_items: Array = level_resource.get_positive_items(track_key)
	positive_items = _level_manager.filter_items_by_category(positive_items, category_code)
	positive_items.shuffle()
	for item_index in range(level_resource.cantidadPositivos):
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

	var negative_items: Array = level_resource.get_negative_items(track_key)
	negative_items = _level_manager.filter_items_by_category(negative_items, category_code)
	negative_items.shuffle()
	for item_index in range(level_resource.cantidadNegativos):
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
