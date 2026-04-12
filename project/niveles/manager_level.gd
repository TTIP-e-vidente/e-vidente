extends Node
class_name ManagerLevel

const LevelMechanicRegistry := preload("res://niveles/mechanics/LevelMechanicRegistry.gd")
const LevelSceneRefsScript := preload("res://niveles/helpers/LevelSceneRefs.gd")
const LevelItemRuntimeScript := preload("res://niveles/helpers/LevelItemRuntime.gd")

@export var level_resource: LevelResource

@onready var plato: Plato = %Plato

@onready var condition_sprite: Sprite2D = $"../Globo texto/Condition"
@onready var meal_sprite: Sprite2D = $"../Globo texto/Meal"
@onready var teaching_sprite: Sprite2D = $"../Ensenanza"
var level_items: Array = []
var active_track_key: String = ""
var active_run_index: int = 1
var active_run_data: Dictionary = {}
var active_mechanic_type: String = ""
var _mechanic_controllers: Dictionary = {}
var _active_mechanic_controller = null
var _scene_refs = null
var _item_runtime = null


func _ready() -> void:
	_ensure_runtime_services()
	_register_mechanics()


func initialize_level_runtime(level_scene: Node) -> void:
	_ensure_runtime_services()
	if not _scene_refs.bind_level_scene_nodes():
		return
	active_track_key = _resolve_level_scene_track_key(level_scene)
	if level_resource != null:
		level_resource.clear_track_pool_cache()
	var saved_progress_snapshot: Dictionary = Global.get_partial_level_state(
		active_track_key,
		_current_level_number()
	)
	active_run_index = _resolve_saved_run_index(saved_progress_snapshot)
	_restore_or_start_active_run(saved_progress_snapshot)


func advance_to_next_run() -> bool:
	if active_run_index >= get_total_runs():
		return false
	active_run_index += 1
	_restore_or_start_active_run({Global.PARTIAL_LEVEL_RUN_INDEX_KEY: active_run_index})
	return true


func get_current_run_index() -> int:
	return active_run_index


func get_total_runs() -> int:
	return max(1, Global.get_chapter_run_count(active_track_key, _current_level_number()))


func _restore_or_start_active_run(saved_progress_snapshot: Dictionary) -> void:
	if _active_mechanic_controller != null:
		_active_mechanic_controller.clear_runtime_state()
	else:
		clear_runtime_items()
	active_run_data = Global.get_chapter_run_definition(
		active_track_key,
		_current_level_number(),
		active_run_index
	)
	if active_run_data.is_empty():
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d corrida %d."
			% [active_track_key, _current_level_number(), active_run_index]
		)
		return
	if not _configure_active_run_runtime():
		return
	_active_mechanic_controller.restore_or_start(saved_progress_snapshot)


func _configure_active_run_runtime() -> bool:
	_ensure_runtime_services()
	active_mechanic_type = LevelMechanicRegistry.normalize_mechanic_type(
		active_run_data.get("mechanic_type", "")
	)
	_active_mechanic_controller = _resolve_mechanic_controller(active_mechanic_type)
	if _active_mechanic_controller == null:
		push_error(
			"ManagerLevel no encontro controlador para la mecanica '%s'."
			% active_mechanic_type
		)
		return false
	_active_mechanic_controller.configure_run(active_run_data, level_resource)
	_scene_refs.apply_run_textures_to_scene(level_resource, active_run_data)
	return true


func build_partial_level_state() -> Dictionary:
	if _active_mechanic_controller == null:
		return {}
	var partial_state: Dictionary = _active_mechanic_controller.build_partial_state()
	if partial_state.is_empty():
		return {}
	partial_state[Global.PARTIAL_LEVEL_RUN_INDEX_KEY] = active_run_index
	var stored_mechanic_type: Variant = partial_state.get(
		Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY,
		active_mechanic_type
	)
	partial_state[Global.PARTIAL_LEVEL_MECHANIC_TYPE_KEY] = str(stored_mechanic_type).strip_edges()
	return partial_state


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_state: Dictionary = build_partial_level_state()
	Global.set_partial_level_state(track_key, _current_level_number(), partial_state)
	var summary: Dictionary = {
		"has_partial_state": not partial_state.is_empty(),
		"run_index": active_run_index,
		"run_count": get_total_runs(),
		"mechanic_type": active_mechanic_type
	}
	if _active_mechanic_controller != null:
		summary.merge(_active_mechanic_controller.build_partial_summary(partial_state), true)
	return summary


func get_positive_items_in_plate_count() -> int:
	if _active_mechanic_controller == null:
		return 0
	return _active_mechanic_controller.get_progress_count()


func filter_items_by_category(items: Array, category: String) -> Array:
	return Global.filter_items_by_category(items, category)


func spawn_level_item(level_item: LevelItem, instance_id: String, is_positive: bool):
	_ensure_runtime_services()
	return _item_runtime.spawn_level_item_instance(level_item, instance_id, is_positive)


func clear_runtime_items() -> void:
	_ensure_runtime_services()
	_item_runtime.clear_runtime_items()


func layout_runtime_items() -> void:
	_ensure_runtime_services()
	_item_runtime.position_runtime_items(level_resource)


func _resolve_saved_run_index(saved_partial_state: Dictionary) -> int:
	return clampi(
		int(saved_partial_state.get(Global.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)),
		1,
		get_total_runs()
	)


func _resolve_level_scene_track_key(level_scene: Node) -> String:
	if level_scene == null or not level_scene.has_method("_get_resume_track_key"):
		return ""
	return str(level_scene.call("_get_resume_track_key")).strip_edges()


func _current_level_number() -> int:
	return Global.get_current_level_number()


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
func _ensure_runtime_services() -> void:
	if _scene_refs == null:
		_scene_refs = LevelSceneRefsScript.new(self)
	if _item_runtime == null:
		_item_runtime = LevelItemRuntimeScript.new(self)
