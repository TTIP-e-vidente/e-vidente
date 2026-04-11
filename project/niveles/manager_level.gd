extends Node
class_name ManagerLevel

const LevelMechanicRegistry := preload("res://niveles/mechanics/LevelMechanicRegistry.gd")

@export var level_resource: LevelResource

@onready var plato: Plato = %Plato

var item_spawn_position: Vector2
var spawned_items: Array = []
@onready var condition_sprite: Sprite2D = $"../Globo texto/Condition"
@onready var meal_sprite: Sprite2D = $"../Globo texto/Meal"
@onready var teaching_sprite: Sprite2D = $"../Ensenanza"
var current_track_key := ""
var current_run_index := 1
var current_run_data: Dictionary = {}
var current_mechanic_type := ""
var _mechanic_controllers: Dictionary = {}
var _active_mechanic_controller = null


func _ready() -> void:
	_register_mechanics()


func setup(level_scene: Node) -> void:
	if not _ensure_level_references():
		return
	current_track_key = ""
	if level_scene != null and level_scene.has_method("_get_resume_track_key"):
		current_track_key = str(level_scene._get_resume_track_key()).strip_edges()
	if level_resource != null:
		level_resource.clear_track_pool_cache()
	var saved_level_state := Global.get_partial_level_state(current_track_key, Global.current_level)
	current_run_index = _resolve_saved_run_index(saved_level_state)
	_load_current_run(saved_level_state)


func advance_to_next_run() -> bool:
	if current_run_index >= get_total_runs():
		return false
	current_run_index += 1
	_load_current_run({Global.PARTIAL_LEVEL_RUN_INDEX_KEY: current_run_index})
	return true


func get_current_run_index() -> int:
	return current_run_index


func get_total_runs() -> int:
	return max(1, Global.get_chapter_run_count(current_track_key, Global.current_level))


func build_partial_save_state() -> Dictionary:
	if _active_mechanic_controller == null:
		return {}
	var partial_state: Dictionary = _active_mechanic_controller.build_partial_state()
	if partial_state.is_empty():
		return {}
	partial_state[Global.PARTIAL_LEVEL_RUN_INDEX_KEY] = current_run_index
	partial_state[Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY] = str(partial_state.get(Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, current_mechanic_type)).strip_edges()
	return partial_state


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_state: Dictionary = build_partial_save_state()
	Global.set_partial_level_state(track_key, Global.current_level, partial_state)
	var summary: Dictionary = {
		"has_partial_state": not partial_state.is_empty(),
		"run_index": current_run_index,
		"run_count": get_total_runs(),
		"mechanic_type": current_mechanic_type
	}
	if _active_mechanic_controller != null:
		summary.merge(_active_mechanic_controller.build_partial_summary(partial_state), true)
	return summary


func get_positive_items_in_plate_count() -> int:
	if _active_mechanic_controller == null:
		return 0
	return _active_mechanic_controller.get_progress_count()


func _layout_items() -> void:
	if (level_resource.cantidadNegativos + level_resource.cantidadPositivos) < 5:
		item_spawn_position = Vector2(420, 680)
	else:
		item_spawn_position = Vector2(230, 680)
	for item in spawned_items:
		item.set_home_position(item_spawn_position)
		item_spawn_position.x += 120


func _load_current_run(saved_level_state: Dictionary) -> void:
	_clear_current_mechanic_state()
	current_run_data = Global.get_chapter_run_definition(current_track_key, Global.current_level, current_run_index)
	if current_run_data.is_empty():
		push_error("ManagerLevel no encontro datos para %s capitulo %d corrida %d." % [current_track_key, Global.current_level, current_run_index])
		return
	if not _apply_current_run_data():
		return
	_active_mechanic_controller.restore_or_start(saved_level_state)


func _apply_current_run_data() -> bool:
	level_resource.comida = Global.resolve_texture(current_run_data.get("meal_texture_path", ""))
	level_resource.condicion = Global.resolve_texture(current_run_data.get("condition_texture_path", ""))
	level_resource.ensenanza = Global.resolve_texture(current_run_data.get("teaching_texture_path", ""))
	current_mechanic_type = _resolve_run_mechanic_type(current_run_data)
	_active_mechanic_controller = _resolve_mechanic_controller(current_mechanic_type)
	if _active_mechanic_controller == null:
		push_error("ManagerLevel no encontro controlador para la mecanica '%s'." % current_mechanic_type)
		return false
	_active_mechanic_controller.configure_run(current_run_data, level_resource)
	return true


func _resolve_saved_run_index(saved_level_state: Dictionary) -> int:
	return clampi(int(saved_level_state.get(Global.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)), 1, get_total_runs())


func _resolve_run_mechanic_type(run_data: Dictionary) -> String:
	return LevelMechanicRegistry.normalize_mechanic_type(run_data.get("mechanic_type", ""))


func _register_mechanics() -> void:
	_mechanic_controllers = LevelMechanicRegistry.build_controllers(self)


func _resolve_mechanic_controller(mechanic_type: String):
	if _mechanic_controllers.is_empty():
		_register_mechanics()
	var clean_mechanic_type: String = mechanic_type.strip_edges()
	if _mechanic_controllers.has(clean_mechanic_type):
		return _mechanic_controllers[clean_mechanic_type]
	return null


func _clear_current_mechanic_state() -> void:
	if _active_mechanic_controller != null:
		_active_mechanic_controller.clear_runtime_state()
		return
	_clear_spawned_items()


func _instantiate_level_item(level_item: LevelItem, instance_id: String, is_positive: bool):
	var new_item = level_item.escena.instantiate()
	if new_item == null:
		return null
	new_item.setup(level_item, plato, is_positive, instance_id)
	add_child(new_item)
	spawned_items.append(new_item)
	return new_item


func _clear_spawned_items() -> void:
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items = []
	plato.elementos.clear()
	plato.cantAlimentosPos.clear()
	plato.cantAlimentosNeg.clear()


func _ensure_level_references() -> bool:
	var level_root := get_parent()
	if level_root == null:
		push_error("ManagerLevel no encontro la escena de nivel contenedora.")
		return false
	if not is_instance_valid(plato):
		plato = level_root.get_node_or_null("Plato") as Plato
	if not is_instance_valid(meal_sprite):
		meal_sprite = level_root.get_node_or_null("Globo texto/Meal") as Sprite2D
	if not is_instance_valid(condition_sprite):
		condition_sprite = level_root.get_node_or_null("Globo texto/Condition") as Sprite2D
	if not is_instance_valid(teaching_sprite):
		teaching_sprite = level_root.get_node_or_null("Ensenanza") as Sprite2D
	if not is_instance_valid(plato) or not is_instance_valid(meal_sprite) or not is_instance_valid(condition_sprite) or not is_instance_valid(teaching_sprite):
		push_error("ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual.")
		return false
	return true
