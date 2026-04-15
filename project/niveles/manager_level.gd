extends Node
class_name ManagerLevel

const LevelMechanicRegistry := preload("res://niveles/mechanics/LevelMechanicRegistry.gd")
const LevelSceneRefsScript := preload("res://niveles/runtime/LevelSceneRefs.gd")
const LevelItemRuntimeScript := preload("res://niveles/runtime/LevelItemRuntime.gd")
const GlobalStateScript := preload("res://niveles/global.gd")
const LevelResourceScript := preload("res://resources/level_resource.gd")
const GameLevelContentCatalogScript := preload(
	"res://niveles/content/GameLevelContentCatalog.gd"
)

@export var level_resource = null
@export var level_resource_path := ""

@onready var plato = %Plato

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
var _global_state = null
var _content_catalog = null


func _ready() -> void:
	_warm_up_runtime_support()


func start_level_session(level_scene: Node) -> void:
	_warm_up_runtime_support()
	if not _scene_refs.connect_scene_nodes(level_scene):
		return

	active_track_key = _read_track_key_from_scene(level_scene)
	_ensure_level_resource_loaded()
	if _is_valid_level_resource(level_resource):
		level_resource.clear_track_pool_cache()

	var global_state: Node = _get_global_state()
	var saved_level_state: Dictionary = {}
	if global_state != null:
		saved_level_state = global_state.get_partial_level_state(
			active_track_key,
			_get_current_level_number()
		)

	active_run_index = clampi(
		int(
			saved_level_state.get(
				GlobalStateScript.PARTIAL_LEVEL_RUN_INDEX_KEY,
				1
			)
		),
		1,
		get_total_runs()
	)
	_start_current_run(saved_level_state)


func initialize_level_runtime(level_scene: Node) -> void:
	start_level_session(level_scene)


func advance_to_next_run() -> bool:
	if active_run_index >= get_total_runs():
		return false
	active_run_index += 1
	_start_current_run({
		GlobalStateScript.PARTIAL_LEVEL_RUN_INDEX_KEY: active_run_index
	})
	return true


func get_current_run_index() -> int:
	return active_run_index


func get_total_runs() -> int:
	_ensure_runtime_support()
	var current_level_number: int = _get_current_level_number()
	return max(
		1,
		_content_catalog.get_chapter_run_count(
			active_track_key,
			current_level_number
		)
	)


func build_partial_level_state() -> Dictionary:
	if _active_mechanic_controller == null:
		return {}

	var partial_level_state: Dictionary = _active_mechanic_controller.build_partial_state()
	if partial_level_state.is_empty():
		return {}

	partial_level_state[GlobalStateScript.PARTIAL_LEVEL_RUN_INDEX_KEY] = active_run_index
	partial_level_state[GlobalStateScript.PARTIAL_LEVEL_MECHANIC_TYPE_KEY] = str(
		partial_level_state.get(
			GlobalStateScript.PARTIAL_LEVEL_MECHANIC_TYPE_KEY,
			active_mechanic_type
		)
	).strip_edges()
	return partial_level_state


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_level_state: Dictionary = build_partial_level_state()
	var global_state: Node = _get_global_state()
	if global_state != null:
		global_state.set_partial_level_state(
			track_key,
			_get_current_level_number(),
			partial_level_state
		)

	var summary: Dictionary = {
		"has_partial_state": not partial_level_state.is_empty(),
		"run_index": active_run_index,
		"run_count": get_total_runs(),
		"mechanic_type": active_mechanic_type
	}
	if _active_mechanic_controller != null:
		summary.merge(
			_active_mechanic_controller.build_partial_summary(partial_level_state),
			true
		)
	return summary


func get_positive_items_in_plate_count() -> int:
	if _active_mechanic_controller == null:
		return 0
	return _active_mechanic_controller.get_progress_count()


func has_completed_current_run() -> bool:
	if not is_instance_valid(plato):
		return false
	if not _is_valid_level_resource(level_resource):
		return false
	return (
		int(level_resource.cantidadPositivos) == get_positive_items_in_plate_count()
		and plato.cantAlimentosNeg.is_empty()
	)


func filter_items_by_category(items: Array, category: String) -> Array:
	_ensure_runtime_support()
	return _content_catalog.filter_items_by_category(items, category)


func spawn_level_item(level_item, instance_id: String, is_positive: bool):
	_ensure_runtime_support()
	return _item_runtime.create_item(level_item, instance_id, is_positive)


func clear_runtime_items() -> void:
	_ensure_runtime_support()
	_item_runtime.clear_items()


func layout_runtime_items() -> void:
	_ensure_runtime_support()
	_item_runtime.layout_items(level_resource)



func _start_current_run(saved_level_state: Dictionary) -> void:
	if _active_mechanic_controller != null:
		_active_mechanic_controller.clear_runtime_state()
	else:
		clear_runtime_items()

	_ensure_runtime_support()
	active_run_data = _content_catalog.get_chapter_run_definition(
		active_track_key,
		_get_current_level_number(),
		active_run_index
	)
	if active_run_data.is_empty():
		active_mechanic_type = ""
		_active_mechanic_controller = null
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d corrida %d."
			% [active_track_key, _get_current_level_number(), active_run_index]
		)
		return

	active_mechanic_type = LevelMechanicRegistry.normalize_mechanic_type(
		active_run_data.get("mechanic_type", "")
	)
	_ensure_mechanic_controllers()
	_active_mechanic_controller = _mechanic_controllers.get(active_mechanic_type)
	if _active_mechanic_controller == null:
		push_error(
			"ManagerLevel no encontro controlador para la mecanica '%s'."
			% active_mechanic_type
		)
		return

	_active_mechanic_controller.configure_run(active_run_data, level_resource)
	_scene_refs.apply_run_textures(level_resource, active_run_data)
	_active_mechanic_controller.restore_or_start(saved_level_state)


func _read_track_key_from_scene(level_scene: Node) -> String:
	if level_scene != null and level_scene.has_method("_get_resume_track_key"):
		return str(level_scene.call("_get_resume_track_key")).strip_edges()
	return ""


func _ensure_level_resource_loaded() -> void:
	if _is_valid_level_resource(level_resource):
		return

	var resolved_resource_path: String = level_resource_path.strip_edges()
	if resolved_resource_path.is_empty():
		level_resource = LevelResourceScript.new()
		return

	var loaded_level_resource: Variant = load(resolved_resource_path)
	if _is_valid_level_resource(loaded_level_resource):
		level_resource = loaded_level_resource
		return

	push_error(
		"ManagerLevel no pudo cargar level_resource en %s." % resolved_resource_path
	)
	level_resource = LevelResourceScript.new()


func _is_valid_level_resource(raw_level_resource: Variant) -> bool:
	return (
		raw_level_resource is Resource
		and raw_level_resource.has_method("get_positive_items")
		and raw_level_resource.has_method("get_negative_items")
		and raw_level_resource.has_method("clear_track_pool_cache")
	)


func _warm_up_runtime_support() -> void:
	_ensure_runtime_support()
	_ensure_mechanic_controllers()


func _ensure_mechanic_controllers() -> void:
	if not _mechanic_controllers.is_empty():
		return
	_mechanic_controllers = LevelMechanicRegistry.build_controllers(self)


func _ensure_runtime_support() -> void:
	if _content_catalog == null:
		_content_catalog = GameLevelContentCatalogScript.new()
	if _scene_refs == null:
		_scene_refs = LevelSceneRefsScript.new(self)
	if _item_runtime == null:
		_item_runtime = LevelItemRuntimeScript.new(self)
	if _global_state == null or not is_instance_valid(_global_state):
		_global_state = _resolve_global_state()


func _get_global_state() -> Node:
	if _global_state == null or not is_instance_valid(_global_state):
		_global_state = _resolve_global_state()
	return _global_state


func _resolve_global_state() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_root().get_node_or_null("Global")


func _get_current_level_number() -> int:
	var global_state = _get_global_state()
	if global_state == null:
		return 1
	return int(global_state.get_current_level_number())
