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
	if not _prepare_level_session(level_scene):
		return
	_restore_saved_run()


func initialize_level_runtime(level_scene: Node) -> void:
	start_level_session(level_scene)


func _prepare_level_session(level_scene: Node) -> bool:
	_warm_up_runtime_support()
	if not _bind_level_scene(level_scene):
		return false

	active_track_key = _read_track_key_from_scene(level_scene)
	_prepare_level_resource_for_runtime()
	return true


func _restore_saved_run() -> void:
	var saved_level_state: Dictionary = _read_saved_partial_level_state()
	active_run_index = _resolve_run_index_from_saved_state(saved_level_state)
	_load_active_run(saved_level_state)


func advance_to_next_run() -> bool:
	if not _can_advance_to_next_run():
		return false
	active_run_index += 1
	_load_requested_run(active_run_index)
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
	return _append_active_run_context(partial_level_state)


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_level_state: Dictionary = build_partial_level_state()
	_write_partial_level_state(track_key, partial_level_state)
	return _build_partial_level_summary(partial_level_state)


func _write_partial_level_state(
	track_key: String,
	partial_level_state: Dictionary
) -> void:
	var global_state: Node = _get_global_state()
	if global_state == null:
		return
	global_state.set_partial_level_state(
		track_key,
		_get_current_level_number(),
		partial_level_state
	)


func _build_partial_level_summary(partial_level_state: Dictionary) -> Dictionary:
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


func _load_active_run(saved_level_state: Dictionary) -> void:
	_clear_previous_run_runtime()
	if not _select_active_run_definition():
		return
	if not _select_active_mechanic_controller():
		return
	_configure_active_run_runtime()
	_restore_active_run(saved_level_state)


func _select_active_run_definition() -> bool:
	active_run_data = _read_active_run_definition()
	if active_run_data.is_empty():
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d corrida %d."
			% [active_track_key, _get_current_level_number(), active_run_index]
		)
		return false
	return true


func _select_active_mechanic_controller() -> bool:
	_active_mechanic_controller = _resolve_run_mechanic_controller(active_run_data)
	if _active_mechanic_controller == null:
		push_error(
			"ManagerLevel no encontro controlador para la mecanica '%s'."
			% active_mechanic_type
		)
		return false
	return true


func _restore_active_run(saved_level_state: Dictionary) -> void:
	_active_mechanic_controller.restore_or_start(saved_level_state)


func _configure_active_run_runtime() -> void:
	_active_mechanic_controller.configure_run(active_run_data, level_resource)
	_scene_refs.apply_run_textures(level_resource, active_run_data)


func _read_track_key_from_scene(level_scene: Node) -> String:
	if level_scene != null and level_scene.has_method("_get_resume_track_key"):
		return str(level_scene.call("_get_resume_track_key")).strip_edges()
	return ""


func _prepare_level_resource_for_runtime() -> void:
	_ensure_level_resource_loaded()
	_clear_level_resource_track_pool_cache()


func _clear_level_resource_track_pool_cache() -> void:
	if _is_valid_level_resource(level_resource):
		level_resource.clear_track_pool_cache()


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


func _read_saved_partial_level_state() -> Dictionary:
	var global_state: Node = _get_global_state()
	if global_state == null:
		return {}
	return global_state.get_partial_level_state(
		active_track_key,
		_get_current_level_number()
	)


func _resolve_run_index_from_saved_state(saved_level_state: Dictionary) -> int:
	return clampi(
		int(
			saved_level_state.get(
				GlobalStateScript.PARTIAL_LEVEL_RUN_INDEX_KEY,
				1
			)
		),
		1,
		get_total_runs()
	)


func _build_run_restore_state(run_index: int) -> Dictionary:
	return {GlobalStateScript.PARTIAL_LEVEL_RUN_INDEX_KEY: run_index}


func _load_requested_run(run_index: int) -> void:
	_load_active_run(_build_run_restore_state(run_index))


func _clear_previous_run_runtime() -> void:
	if _active_mechanic_controller != null:
		_active_mechanic_controller.clear_runtime_state()
		return
	clear_runtime_items()


func _read_active_run_definition() -> Dictionary:
	_ensure_runtime_support()
	var current_level_number: int = _get_current_level_number()
	return _content_catalog.get_chapter_run_definition(
		active_track_key,
		current_level_number,
		active_run_index
	)


func _resolve_run_mechanic_controller(run_data: Dictionary):
	active_mechanic_type = LevelMechanicRegistry.normalize_mechanic_type(
		run_data.get("mechanic_type", "")
	)
	_ensure_mechanic_controllers()
	return _mechanic_controllers.get(active_mechanic_type)


func _append_active_run_context(partial_level_state: Dictionary) -> Dictionary:
	if partial_level_state.is_empty():
		return {}
	partial_level_state[GlobalStateScript.PARTIAL_LEVEL_RUN_INDEX_KEY] = active_run_index
	partial_level_state[GlobalStateScript.PARTIAL_LEVEL_MECHANIC_TYPE_KEY] = (
		_resolve_partial_state_mechanic_type(partial_level_state)
	)
	return partial_level_state


func _resolve_partial_state_mechanic_type(partial_level_state: Dictionary) -> String:
	var stored_mechanic_type: Variant = partial_level_state.get(
		GlobalStateScript.PARTIAL_LEVEL_MECHANIC_TYPE_KEY,
		active_mechanic_type
	)
	return str(stored_mechanic_type).strip_edges()


func _can_advance_to_next_run() -> bool:
	return active_run_index < get_total_runs()


func _bind_level_scene(level_scene: Node) -> bool:
	return _scene_refs.connect_scene_nodes(level_scene)


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
