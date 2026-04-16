extends Node
class_name ManagerLevel

const LevelSceneRefsScript := preload("res://niveles/runtime/LevelSceneRefs.gd")
const LevelItemRuntimeScript := preload("res://niveles/runtime/LevelItemRuntime.gd")
const GameProgressKeys := preload("res://niveles/progress/GameProgressKeys.gd")
const LevelResourceScript := preload("res://resources/level_resource.gd")
const GameLevelContentCatalogScript := preload(
	"res://niveles/content/GameLevelContentCatalog.gd"
)

const PLATE_SORT_MECHANIC_TYPE := "plate_sort"
const MAX_PLATE_COLUMNS := 3
const PLATE_ITEM_COLUMN_SPACING := 78.0
const PLATE_ITEM_ROW_SPACING := 48.0
const PLATE_ITEM_VERTICAL_OFFSET := -12.0

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
var _scene_refs = null
var _item_runtime = null
var _global_state = null
var _content_catalog = null


func _ready() -> void:
	_ensure_runtime_support()


func start_level_session(level_scene: Node) -> void:
	_ensure_runtime_support()
	if not _scene_refs.connect_scene_nodes(level_scene):
		return

	active_track_key = _resolve_track_key_from_scene(level_scene)
	_ensure_level_resource_loaded()
	_clear_level_resource_track_cache()

	var saved_level_state: Dictionary = _read_saved_level_state()
	active_run_index = clampi(
		int(saved_level_state.get(GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY, 1)),
		1,
		get_total_runs()
	)
	_load_current_run(saved_level_state)


func initialize_level_runtime(level_scene: Node) -> void:
	start_level_session(level_scene)


func advance_to_next_run() -> bool:
	if active_run_index >= get_total_runs():
		return false
	active_run_index += 1
	_load_current_run({
		GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY: active_run_index
	})
	return true


func get_current_run_index() -> int:
	return active_run_index


func get_total_runs() -> int:
	_ensure_runtime_support()
	var level_number := _get_current_level_number()
	return max(
		1,
		_content_catalog.get_chapter_run_count(
			active_track_key,
			level_number
		)
	)


func build_partial_level_state() -> Dictionary:
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		return {}

	var saved_item_entries: Array = []
	var placed_positive_item_ids: Array = []

	for runtime_item in level_items:
		if not is_instance_valid(runtime_item):
			continue

		var item_path: String = str(runtime_item.item_resource_path).strip_edges()
		var instance_id: String = str(runtime_item.save_instance_id).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue

		var saved_item_entry: Dictionary = {
			GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY: item_path,
			GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY: instance_id,
			GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY: bool(runtime_item.esPositivo)
		}
		saved_item_entries.append(saved_item_entry)

		if bool(runtime_item.esPositivo) and plato.has_positive_item(runtime_item):
			placed_positive_item_ids.append(instance_id)

	if saved_item_entries.is_empty() and active_run_index <= 1:
		return {}

	var mechanic_state: Dictionary = {
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: saved_item_entries,
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}
	return {
		GameProgressKeys.PARTIAL_LEVEL_RUN_INDEX_KEY: active_run_index,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_TYPE_KEY: active_mechanic_type,
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY: mechanic_state,
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: saved_item_entries,
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_positive_item_ids
	}


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_level_state: Dictionary = build_partial_level_state()
	var global_state: Node = _get_global_state()
	if global_state != null:
		global_state.set_partial_level_state(
			track_key,
			_get_current_level_number(),
			partial_level_state
		)
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		return {}

	var saved_plate_sort_state: Dictionary = _read_saved_plate_sort_state(partial_level_state)
	var raw_saved_positive_item_ids: Variant = saved_plate_sort_state.get(
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	var placed_positive_item_ids: Array = (
		raw_saved_positive_item_ids if raw_saved_positive_item_ids is Array else []
	)
	var placed_item_count: int = placed_positive_item_ids.size()
	return {
		"placed_positive_count": placed_item_count,
		"progress_count": placed_item_count,
		"progress_unit_singular": "alimento correcto en el plato",
		"progress_unit_plural": "alimentos correctos en el plato"
	}


func get_positive_items_in_plate_count() -> int:
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE or not is_instance_valid(plato):
		return 0
	return plato.cantAlimentosPos.size()


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



func _load_current_run(saved_level_state: Dictionary) -> void:
	_clear_current_run_runtime()

	_ensure_runtime_support()
	var level_number := _get_current_level_number()
	active_run_data = _content_catalog.get_chapter_run_definition(
		active_track_key,
		level_number,
		active_run_index
	)
	if active_run_data.is_empty():
		_reset_active_run_state()
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d corrida %d."
			% [active_track_key, level_number, active_run_index]
		)
		return

	active_mechanic_type = str(active_run_data.get("mechanic_type", "")).strip_edges()
	if active_mechanic_type.is_empty():
		active_mechanic_type = PLATE_SORT_MECHANIC_TYPE
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		push_error(
			"ManagerLevel no soporta la mecanica '%s'."
			% active_mechanic_type
		)
		return

	var stored_mechanic_payload: Variant = active_run_data.get("mechanic_payload", {})
	var run_payload: Dictionary = {}
	if (
		stored_mechanic_payload is Dictionary
		and not (stored_mechanic_payload as Dictionary).is_empty()
	):
		run_payload = (stored_mechanic_payload as Dictionary).duplicate(true)
	else:
		run_payload = {
			"negative_count": int(active_run_data.get("negative_count", 0)),
			"positive_count": int(active_run_data.get("positive_count", 0)),
			"category": str(active_run_data.get("category", ""))
		}

	level_resource.mechanic_type = active_mechanic_type
	level_resource.mechanic_payload = run_payload
	level_resource.cantidadNegativos = int(run_payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(run_payload.get("positive_count", 0))
	_scene_refs.apply_run_textures(level_resource, active_run_data)

	var saved_plate_sort_state: Dictionary = _read_saved_plate_sort_state(saved_level_state)
	var raw_saved_items: Variant = saved_plate_sort_state.get(
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY,
		[]
	)
	var saved_item_entries: Array = raw_saved_items if raw_saved_items is Array else []
	if _restore_saved_plate_sort_items(saved_item_entries):
		layout_runtime_items()
		_restore_saved_items_in_plate(saved_plate_sort_state)
		return

	_spawn_plate_sort_items_for_run(run_payload)
	level_items.shuffle()
	layout_runtime_items()


func _resolve_track_key_from_scene(level_scene: Node) -> String:
	if level_scene != null and level_scene.has_method("_get_resume_track_key"):
		return str(level_scene.call("_get_resume_track_key")).strip_edges()
	return ""


func _read_saved_level_state() -> Dictionary:
	var global_state := _get_global_state()
	if global_state == null:
		return {}
	return global_state.get_partial_level_state(
		active_track_key,
		_get_current_level_number()
	)


func _clear_level_resource_track_cache() -> void:
	if _is_valid_level_resource(level_resource):
		level_resource.clear_track_pool_cache()


func _clear_current_run_runtime() -> void:
	clear_runtime_items()


func _reset_active_run_state() -> void:
	active_run_data = {}
	active_mechanic_type = ""


func _spawn_plate_sort_items_for_run(run_payload: Dictionary) -> void:
	var track_key: String = active_track_key
	var category_code: String = str(run_payload.get("category", ""))

	var positive_items: Array = filter_items_by_category(
		level_resource.get_positive_items(track_key),
		category_code
	)
	positive_items.shuffle()
	for item_index in range(level_resource.cantidadPositivos):
		if positive_items.is_empty():
			break
		var level_item = positive_items.pop_front()
		if level_item == null:
			continue
		spawn_level_item(level_item, "positive_%d" % item_index, true)

	var negative_items: Array = filter_items_by_category(
		level_resource.get_negative_items(track_key),
		category_code
	)
	negative_items.shuffle()
	for item_index in range(level_resource.cantidadNegativos):
		if negative_items.is_empty():
			break
		var level_item = negative_items.pop_front()
		if level_item == null:
			continue
		spawn_level_item(level_item, "negative_%d" % item_index, false)


func _read_saved_plate_sort_state(saved_level_state: Dictionary) -> Dictionary:
	var raw_mechanic_state: Variant = saved_level_state.get(
		GameProgressKeys.PARTIAL_LEVEL_MECHANIC_STATE_KEY,
		{}
	)
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		return (raw_mechanic_state as Dictionary).duplicate(true)
	return {
		GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY: saved_level_state.get(
			GameProgressKeys.PARTIAL_LEVEL_ITEMS_KEY,
			[]
		),
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: saved_level_state.get(
			GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
			[]
		)
	}


func _restore_saved_plate_sort_items(saved_item_entries: Array) -> bool:
	if saved_item_entries.is_empty():
		return false

	for raw_saved_item in saved_item_entries:
		if not _restore_saved_runtime_item(raw_saved_item):
			clear_runtime_items()
			return false

	return not level_items.is_empty()


func _restore_saved_items_in_plate(saved_plate_sort_state: Dictionary) -> void:
	var raw_saved_positive_item_ids: Variant = saved_plate_sort_state.get(
		GameProgressKeys.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY,
		[]
	)
	if not raw_saved_positive_item_ids is Array:
		return

	var runtime_positive_items: Array = []
	for raw_item_id in raw_saved_positive_item_ids:
		var instance_id: String = str(raw_item_id).strip_edges()
		if instance_id.is_empty():
			continue

		var runtime_item = _find_runtime_item_by_instance_id(instance_id)
		if runtime_item == null or not runtime_item.esPositivo:
			continue

		runtime_positive_items.append(runtime_item)

	for item_index in range(runtime_positive_items.size()):
		var runtime_item = runtime_positive_items[item_index]
		runtime_item.restore_to_plate(
			_get_plate_position(item_index, runtime_positive_items.size())
		)
		plato.restore_positive_item(runtime_item)


func _restore_saved_runtime_item(raw_saved_item: Variant) -> bool:
	if not raw_saved_item is Dictionary:
		return false

	var saved_item: Dictionary = raw_saved_item
	var item_path: String = str(
		saved_item.get(GameProgressKeys.PARTIAL_LEVEL_ITEM_PATH_KEY, "")
	).strip_edges()
	var instance_id: String = str(
		saved_item.get(GameProgressKeys.PARTIAL_LEVEL_INSTANCE_ID_KEY, "")
	).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false

	var level_item = load(item_path)
	if level_item == null:
		return false

	var is_positive: bool = bool(
		saved_item.get(GameProgressKeys.PARTIAL_LEVEL_IS_POSITIVE_KEY, false)
	)
	return spawn_level_item(level_item, instance_id, is_positive) != null


func _find_runtime_item_by_instance_id(instance_id: String):
	for runtime_item in level_items:
		if not is_instance_valid(runtime_item):
			continue
		if str(runtime_item.save_instance_id) == instance_id:
			return runtime_item
	return null


func _get_plate_position(index: int, total_items: int) -> Vector2:
	var columns: int = clampi(total_items, 1, MAX_PLATE_COLUMNS)
	var row: int = floori(float(index) / float(columns))
	var column: int = index % columns
	var horizontal_origin: float = float(columns - 1) / 2.0
	var offset: Vector2 = Vector2(
		(float(column) - horizontal_origin) * PLATE_ITEM_COLUMN_SPACING,
		float(row) * PLATE_ITEM_ROW_SPACING + PLATE_ITEM_VERTICAL_OFFSET
	)
	return plato.global_position + offset


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
