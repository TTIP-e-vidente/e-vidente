extends LevelMechanicController

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const PlateSortMechanicStateServiceScript := preload(
	"res://niveles/mechanics/PlateSortMechanicStateService.gd"
)

var _state_service


func _init(manager) -> void:
	super(manager)
	_state_service = PlateSortMechanicStateServiceScript.new(manager)


func get_mechanic_type() -> String:
	return LevelMechanicTypes.PLATE_SORT


func configure_run(run_data: Dictionary, level_resource: LevelResource) -> void:
	var payload: Dictionary = _read_run_payload(run_data)
	level_resource.mechanic_type = get_mechanic_type()
	level_resource.mechanic_payload = payload.duplicate(true)
	level_resource.cantidadNegativos = int(payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(payload.get("positive_count", 0))


func restore_or_start(saved_level_state: Dictionary) -> void:
	if _restore_saved_items_and_layout(saved_level_state):
		_restore_saved_plate_progress(saved_level_state)
		return
	_spawn_new_items_and_layout()
	_restore_saved_plate_progress(saved_level_state)


func build_partial_state() -> Dictionary:
	return _state_service.build_partial_state(get_mechanic_type(), _manager.get_current_run_index())


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	return _state_service.build_partial_summary(partial_state)


func get_progress_count() -> int:
	return _manager.plato.cantAlimentosPos.keys().size()


func clear_runtime_state() -> void:
	_manager.clear_runtime_items()


func _read_run_payload(run_data: Dictionary) -> Dictionary:
	var raw_payload: Variant = run_data.get("mechanic_payload", {})
	if raw_payload is Dictionary and not raw_payload.is_empty():
		return (raw_payload as Dictionary).duplicate(true)
	return _build_legacy_run_payload(run_data)


func _build_legacy_run_payload(run_data: Dictionary) -> Dictionary:
	return {
		"negative_count": int(run_data.get("negative_count", 0)),
		"positive_count": int(run_data.get("positive_count", 0)),
		"category": str(run_data.get("category", ""))
	}


func _spawn_random_items() -> void:
	var category_code: String = _current_run_category()
	var positive_candidates: Array = _resolve_spawn_candidates(true, category_code)
	var negative_candidates: Array = _resolve_spawn_candidates(false, category_code)
	_spawn_item_batch(
		positive_candidates,
		_manager.level_resource.cantidadPositivos,
		true
	)
	_spawn_item_batch(
		negative_candidates,
		_manager.level_resource.cantidadNegativos,
		false
	)


func _restore_saved_items_and_layout(saved_level_state: Dictionary) -> bool:
	if not _state_service.spawn_items_from_saved_state(saved_level_state):
		return false
	_manager.layout_runtime_items()
	return true


func _spawn_new_items_and_layout() -> void:
	_spawn_random_items()
	_manager.level_items.shuffle()
	_manager.layout_runtime_items()


func _restore_saved_plate_progress(saved_level_state: Dictionary) -> void:
	_state_service.restore_saved_positive_items(saved_level_state)


func _current_run_category() -> String:
	var run_payload: Dictionary = (
		_manager.level_resource.mechanic_payload
		if _manager.level_resource.mechanic_payload is Dictionary
		else {}
	)
	return str(run_payload.get("category", ""))


func _resolve_spawn_candidates(is_positive: bool, category_code: String) -> Array:
	var track_item_pool: Array = _shuffled_track_item_pool(is_positive)
	return _manager.filter_items_by_category(track_item_pool, category_code)


func _shuffled_track_item_pool(is_positive: bool) -> Array:
	var track_item_pool: Array = (
		_manager.level_resource.get_positive_items(_manager.active_track_key)
		if is_positive
		else _manager.level_resource.get_negative_items(_manager.active_track_key)
	)
	track_item_pool.shuffle()
	return track_item_pool


func _spawn_item_batch(candidate_items: Array, item_count: int, is_positive: bool) -> void:
	for item_index in range(item_count):
		var level_item: LevelItem = _pop_next_level_item(candidate_items)
		if level_item == null:
			continue
		_manager.spawn_level_item(
			level_item,
			_build_spawn_instance_id(is_positive, item_index),
			is_positive
		)


func _pop_next_level_item(candidate_items: Array) -> LevelItem:
	if candidate_items.is_empty():
		return null
	return candidate_items.pop_front() as LevelItem


func _build_spawn_instance_id(is_positive: bool, item_index: int) -> String:
	var item_group: String = "positive" if is_positive else "negative"
	return "%s_%d" % [item_group, item_index]
