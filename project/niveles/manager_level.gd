extends Node
class_name ManagerLevel

const LevelMechanicRegistry := preload("res://niveles/mechanics/LevelMechanicRegistry.gd")
const LevelSceneRefsScript := preload("res://niveles/helpers/LevelSceneRefs.gd")
const LevelItemRuntimeScript := preload("res://niveles/helpers/LevelItemRuntime.gd")

@export var level_resource: LevelResource

@onready var plato: Plato = %Plato

var spawned_items: Array = []
var lista_items: Array:
	get:
		return spawned_items
	set(value):
		spawned_items = value
@onready var condition_sprite: Sprite2D = $"../Globo texto/Condition"
@onready var meal_sprite: Sprite2D = $"../Globo texto/Meal"
@onready var teaching_sprite: Sprite2D = $"../Ensenanza"
var current_track_key := ""
var current_run_index := 1
var current_run_definition: Dictionary = {}
var current_mechanic_type := ""
var _mechanic_controllers: Dictionary = {}
var _active_mechanic_controller = null
var _scene_refs = null
var _item_runtime = null


func _ready() -> void:
	_ensure_runtime_services()
	_register_mechanics()


func setup(level_scene: Node) -> void:
	_ensure_runtime_services()
	if not _bind_level_scene_nodes():
		return
	_initialize_runtime_from_scene(level_scene)


func _initialize_runtime_from_scene(level_scene: Node) -> void:
	current_track_key = _resolve_track_key_from_scene(level_scene)
	_clear_track_pool_cache()
	var saved_partial_state := _load_saved_partial_state()
	current_run_index = _resolve_saved_run_index(saved_partial_state)
	_load_active_run(saved_partial_state)


func _clear_track_pool_cache() -> void:
	if level_resource != null:
		level_resource.clear_track_pool_cache()


func _load_saved_partial_state() -> Dictionary:
	return Global.get_partial_level_state(current_track_key, Global.current_level)


func advance_to_next_run() -> bool:
	if current_run_index >= get_total_runs():
		return false
	current_run_index += 1
	_load_active_run({Global.PARTIAL_LEVEL_RUN_INDEX_KEY: current_run_index})
	return true


func get_current_run_index() -> int:
	return current_run_index


func get_total_runs() -> int:
	return max(1, Global.get_chapter_run_count(current_track_key, Global.current_level))


func _load_active_run(saved_partial_state: Dictionary) -> void:
	_clear_current_mechanic_state()
	current_run_definition = _read_current_run_definition()
	if current_run_definition.is_empty():
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d corrida %d."
			% [current_track_key, Global.current_level, current_run_index]
		)
		return
	if not _configure_current_run():
		return
	_active_mechanic_controller.restore_or_start(saved_partial_state)


func _read_current_run_definition() -> Dictionary:
	return Global.get_chapter_run_definition(
		current_track_key,
		Global.current_level,
		current_run_index
	)


func _configure_current_run() -> bool:
	_ensure_runtime_services()
	current_mechanic_type = _resolve_run_mechanic_type(current_run_definition)
	_active_mechanic_controller = _resolve_mechanic_controller(current_mechanic_type)
	if _active_mechanic_controller == null:
		push_error(
			"ManagerLevel no encontro controlador para la mecanica '%s'."
			% current_mechanic_type
		)
		return false
	_active_mechanic_controller.configure_run(current_run_definition, level_resource)
	_scene_refs.apply_run_visuals(level_resource, current_run_definition)
	return true


func build_partial_level_state() -> Dictionary:
	if _active_mechanic_controller == null:
		return {}
	var partial_state: Dictionary = _active_mechanic_controller.build_partial_state()
	if partial_state.is_empty():
		return {}
	partial_state[Global.PARTIAL_LEVEL_RUN_INDEX_KEY] = current_run_index
	partial_state[Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY] = str(
		partial_state.get(Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY, current_mechanic_type)
	).strip_edges()
	return partial_state


func build_partial_save_state() -> Dictionary:
	return build_partial_level_state()


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_state: Dictionary = build_partial_level_state()
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

func filter_items_by_category(items: Array, category: String) -> Array:
	return Global.item_categoria(items, category)


func spawn_level_item(level_item: LevelItem, instance_id: String, is_positive: bool):
	_ensure_runtime_services()
	return _item_runtime.instantiate_level_item(level_item, instance_id, is_positive)


func clear_runtime_items() -> void:
	_ensure_runtime_services()
	_item_runtime.clear_spawned_items()


func layout_runtime_items() -> void:
	_ensure_runtime_services()
	_item_runtime.layout_items(level_resource)
func _resolve_saved_run_index(saved_partial_state: Dictionary) -> int:
	return clampi(
		int(saved_partial_state.get(Global.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)),
		1,
		get_total_runs()
	)


func _resolve_track_key_from_scene(level_scene: Node) -> String:
	if level_scene == null or not level_scene.has_method("_get_resume_track_key"):
		return ""
	return str(level_scene.call("_get_resume_track_key")).strip_edges()


func _resolve_run_mechanic_type(run_definition: Dictionary) -> String:
	return LevelMechanicRegistry.normalize_mechanic_type(
		run_definition.get("mechanic_type", "")
	)


func _register_mechanics() -> void:
	_ensure_runtime_services()
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
	clear_runtime_items()


func _bind_level_scene_nodes() -> bool:
	_ensure_runtime_services()
	return _scene_refs.ensure_level_references()


func _ensure_runtime_services() -> void:
	if _scene_refs == null:
		_scene_refs = LevelSceneRefsScript.new(self)
	if _item_runtime == null:
		_item_runtime = LevelItemRuntimeScript.new(self)
