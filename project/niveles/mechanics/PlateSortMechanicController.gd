extends LevelMechanicController

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
	var run_payload: Dictionary = _resolve_run_payload(run_data)
	_apply_run_payload_to_level_resource(level_resource, run_payload)


func restore_or_start(saved_level_state: Dictionary) -> void:
	var restored_saved_layout: bool = _restore_saved_items_and_layout(saved_level_state)
	if not restored_saved_layout:
		_spawn_new_items_and_layout()
	_restore_saved_plate_progress(saved_level_state)


func build_partial_state() -> Dictionary:
	return _plate_sort_state_service.build_partial_state(
		get_mechanic_type(),
		_level_manager.get_current_run_index()
	)


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	return _plate_sort_state_service.build_partial_summary(partial_state)


func get_progress_count() -> int:
	return _level_manager.plato.cantAlimentosPos.keys().size()


func clear_runtime_state() -> void:
	_level_manager.clear_runtime_items()


func _resolve_run_payload(run_data: Dictionary) -> Dictionary:
	var raw_payload: Variant = run_data.get("mechanic_payload", {})
	if raw_payload is Dictionary and not raw_payload.is_empty():
		return (raw_payload as Dictionary).duplicate(true)
	return _build_legacy_run_payload(run_data)


func _apply_run_payload_to_level_resource(
	level_resource: LevelResource,
	run_payload: Dictionary
) -> void:
	level_resource.mechanic_type = get_mechanic_type()
	level_resource.mechanic_payload = run_payload.duplicate(true)
	level_resource.cantidadNegativos = int(run_payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(run_payload.get("positive_count", 0))


func _build_legacy_run_payload(run_data: Dictionary) -> Dictionary:
	return {
		"negative_count": int(run_data.get("negative_count", 0)),
		"positive_count": int(run_data.get("positive_count", 0)),
		"category": str(run_data.get("category", ""))
	}


func _spawn_items_for_current_run() -> void:
	var category_code: String = _get_current_run_category()
	_spawn_random_items_from_track_pool(
		true,
		_level_manager.level_resource.cantidadPositivos,
		category_code
	)
	_spawn_random_items_from_track_pool(
		false,
		_level_manager.level_resource.cantidadNegativos,
		category_code
	)


func _restore_saved_items_and_layout(saved_level_state: Dictionary) -> bool:
	if not _plate_sort_state_service.spawn_items_from_saved_state(saved_level_state):
		return false
	_level_manager.layout_runtime_items()
	return true


func _spawn_new_items_and_layout() -> void:
	_spawn_items_for_current_run()
	_level_manager.level_items.shuffle()
	_level_manager.layout_runtime_items()


func _restore_saved_plate_progress(saved_level_state: Dictionary) -> void:
	_plate_sort_state_service.restore_saved_positive_items(saved_level_state)


func _get_current_run_category() -> String:
	var run_payload: Dictionary = (
		_level_manager.level_resource.mechanic_payload
		if _level_manager.level_resource.mechanic_payload is Dictionary
		else {}
	)
	return str(run_payload.get("category", ""))


func _spawn_random_items_from_track_pool(
	is_positive: bool,
	item_count: int,
	category_code: String
) -> void:
	var candidate_items: Array = _build_candidate_items_for_run(is_positive, category_code)
	for item_index in range(item_count):
		if candidate_items.is_empty():
			return
		var level_item: LevelItem = candidate_items.pop_front() as LevelItem
		if level_item == null:
			continue
		var item_group: String = "positive" if is_positive else "negative"
		_level_manager.spawn_level_item(
			level_item,
			"%s_%d" % [item_group, item_index],
			is_positive
		)


func _build_candidate_items_for_run(is_positive: bool, category_code: String) -> Array:
	var candidate_items: Array = (
		_level_manager.level_resource.get_positive_items(_level_manager.active_track_key)
		if is_positive
		else _level_manager.level_resource.get_negative_items(_level_manager.active_track_key)
	)
	candidate_items = _level_manager.filter_items_by_category(candidate_items, category_code)
	candidate_items.shuffle()
	return candidate_items
