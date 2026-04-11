extends LevelMechanicController

const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const PlateSortMechanicStateServiceScript := preload("res://niveles/mechanics/PlateSortMechanicStateService.gd")

var _state_service


func _init(manager) -> void:
	super(manager)
	_state_service = PlateSortMechanicStateServiceScript.new(manager)


func get_mechanic_type() -> String:
	return LevelMechanicTypes.PLATE_SORT


func configure_run(run_data: Dictionary, level_resource: LevelResource) -> void:
	var payload: Dictionary = _resolve_payload(run_data)
	level_resource.mechanic_type = get_mechanic_type()
	level_resource.mechanic_payload = payload.duplicate(true)
	level_resource.cantidadNegativos = int(payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(payload.get("positive_count", 0))
	level_resource.comida = Global.resolve_texture(run_data.get("meal_texture_path", ""))
	level_resource.condicion = Global.resolve_texture(run_data.get("condition_texture_path", ""))
	level_resource.ensenanza = Global.resolve_texture(run_data.get("teaching_texture_path", ""))
	_manager.teaching_sprite.texture = level_resource.ensenanza
	_manager.meal_sprite.texture = level_resource.comida
	_manager.condition_sprite.texture = level_resource.condicion


func restore_or_start(saved_level_state: Dictionary) -> void:
	if not _state_service.spawn_items_from_saved_state(saved_level_state):
		_spawn_random_items()
		_manager.lista_items.shuffle()
	_manager._layout_items()
	_state_service.restore_saved_positive_items(saved_level_state)


func build_partial_state() -> Dictionary:
	return _state_service.build_partial_state(get_mechanic_type(), _manager.get_current_run_index())


func build_partial_summary(partial_state: Dictionary) -> Dictionary:
	return _state_service.build_partial_summary(partial_state)


func get_progress_count() -> int:
	return _manager.plato.cantAlimentosPos.keys().size()


func clear_runtime_state() -> void:
	_manager._clear_spawned_items()


func _resolve_payload(run_data: Dictionary) -> Dictionary:
	var raw_payload: Variant = run_data.get("mechanic_payload", {})
	if raw_payload is Dictionary and not raw_payload.is_empty():
		return (raw_payload as Dictionary).duplicate(true)
	return {
		"negative_count": int(run_data.get("negative_count", 0)),
		"positive_count": int(run_data.get("positive_count", 0)),
		"category": str(run_data.get("category", ""))
	}


func _spawn_random_items() -> void:
	var lista_negativos: Array = _manager.level_resource.get_negative_items(_manager.current_track_key)
	var lista_positivos: Array = _manager.level_resource.get_positive_items(_manager.current_track_key)
	lista_negativos.shuffle()
	lista_positivos.shuffle()
	var payload: Dictionary = _manager.level_resource.mechanic_payload if _manager.level_resource.mechanic_payload is Dictionary else {}
	var categoria_actual: String = str(payload.get("category", ""))
	var filtrados_positivos: Array = Global.item_categoria(lista_positivos, categoria_actual)
	var filtrados_negativos: Array = Global.item_categoria(lista_negativos, categoria_actual)
	for index in range(_manager.level_resource.cantidadPositivos):
		var raw_positive_item: Variant = filtrados_positivos.pop_front()
		var positive_item: LevelItem = raw_positive_item as LevelItem
		if positive_item == null:
			continue
		_manager._instantiate_level_item(positive_item, "positive_%d" % index, true)
	for index in range(_manager.level_resource.cantidadNegativos):
		var raw_negative_item: Variant = filtrados_negativos.pop_front()
		var negative_item: LevelItem = raw_negative_item as LevelItem
		if negative_item == null:
			continue
		_manager._instantiate_level_item(negative_item, "negative_%d" % index, false)
