extends Node
class_name ManagerLevel

const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const GameTrackItemPoolCatalogScript := preload(
	"res://niveles/content/catalog/GameTrackItemPoolCatalog.gd"
)
const LevelResourceScript := preload("res://resources/level_resource.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const PLATE_SORT_MECHANIC_TYPE := "plate_sort"
const MAX_PLATE_COLUMNS := 3
const PLATE_ITEM_COLUMN_SPACING := 78.0
const PLATE_ITEM_ROW_SPACING := 48.0
const PLATE_ITEM_VERTICAL_OFFSET := -12.0

@export var level_resource = null
@export var level_resource_path := ""

@onready var plato = %Plato

var condition_sprite: Sprite2D = null
var meal_sprite: Sprite2D = null
var teaching_sprite: Sprite2D = null
var level_items: Array = []
var active_track_key: String = ""
var active_run_index: int = 1
var active_run_data: Dictionary = {}
var active_mechanic_type: String = ""


func start_level_session(track_key: String, level_scene: Node) -> void:
	if not _connect_scene_nodes(level_scene):
		return

	active_track_key = track_key.strip_edges()
	_ensure_level_resource_loaded()

	var saved_level_state: Dictionary = Global.get_partial_level_state(
		active_track_key, Global.current_level
	)
	active_run_index = clampi(
		int(saved_level_state.get("run_index", 1)),
		1,
		get_total_runs()
	)
	_load_current_run(saved_level_state)


func advance_to_next_run() -> bool:
	if active_run_index >= get_total_runs():
		return false
	active_run_index += 1
	_load_current_run({"run_index": active_run_index})
	return true


func get_current_run_index() -> int:
	return active_run_index


func get_total_runs() -> int:
	return max(1, Global.get_chapter_run_count(active_track_key, Global.current_level))


# Solo arma y devuelve el dict de estado parcial. No guarda nada.
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
			"item_path": item_path,
			"instance_id": instance_id,
			"is_positive": bool(runtime_item.esPositivo)
		}
		saved_item_entries.append(saved_item_entry)

		if bool(runtime_item.esPositivo) and plato.has_positive_item(runtime_item):
			placed_positive_item_ids.append(instance_id)

	if saved_item_entries.is_empty() and active_run_index <= 1:
		return {}

	var mechanic_state: Dictionary = {
		"items": saved_item_entries,
		"placed_item_ids": placed_positive_item_ids
	}
	return {
		"run_index": active_run_index,
		"mechanic_type": active_mechanic_type,
		"mechanic_state": mechanic_state
	}


# Arma el estado parcial, lo guarda en Global y devuelve metadata de UI para el feedback.
func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_level_state: Dictionary = build_partial_level_state()
	Global.set_partial_level_state(
		track_key,
		Global.current_level,
		partial_level_state
	)
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		return {}

	var mechanic_state: Dictionary = partial_level_state.get("mechanic_state", {}) as Dictionary
	var placed_item_ids: Array = mechanic_state.get("placed_item_ids", [])
	var placed_item_count: int = placed_item_ids.size()
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
	if level_resource == null:
		return false
	return (
		int(level_resource.cantidadPositivos) == get_positive_items_in_plate_count()
		and plato.cantAlimentosNeg.is_empty()
	)


func filter_items_by_category(items: Array, category: String) -> Array:
	if category.strip_edges().is_empty():
		return items.duplicate()
	var wanted: String = GameTrackCatalog.normalize_category_code(category)
	var result: Array = []
	for item in items:
		if GameTrackCatalog.categories_match(str(item.categoria), wanted):
			result.append(item)
	return result


func spawn_level_item(level_item, instance_id: String, is_positive: bool):
	var level_item_instance = level_item.escena.instantiate()
	if level_item_instance == null:
		return null
	level_item_instance.setup(level_item, plato, is_positive, instance_id)
	add_child(level_item_instance)
	level_items.append(level_item_instance)
	return level_item_instance


func clear_runtime_items() -> void:
	for item in level_items:
		if is_instance_valid(item):
			item.queue_free()
	level_items.clear()
	if not is_instance_valid(plato):
		return
	plato.elementos.clear()
	plato.cantAlimentosPos.clear()
	plato.cantAlimentosNeg.clear()


func layout_runtime_items() -> void:
	var next_item_position := Vector2(230, 680)
	var total_items: int = (
		level_resource.cantidadNegativos + level_resource.cantidadPositivos
	)
	if total_items < 5:
		next_item_position = Vector2(420, 680)
	for item in level_items:
		item.set_home_position(next_item_position)
		next_item_position.x += 120



func _load_current_run(saved_level_state: Dictionary) -> void:
	clear_runtime_items()

	var level_number: int = Global.current_level
	active_run_data = Global.get_chapter_run_definition(
		active_track_key, level_number, active_run_index
	)
	if active_run_data.is_empty():
		active_run_data = {}
		active_mechanic_type = ""
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d corrida %d."
			% [active_track_key, level_number, active_run_index]
		)
		return

	active_mechanic_type = str(active_run_data.get("mechanic_type", "")).strip_edges()
	if active_mechanic_type.is_empty():
		active_mechanic_type = PLATE_SORT_MECHANIC_TYPE
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		push_error("ManagerLevel no soporta la mecanica '%s'." % active_mechanic_type)
		return

	var run_payload: Dictionary = active_run_data.get("mechanic_payload", {}) as Dictionary
	if run_payload.is_empty():
		run_payload = {
			"negative_count": int(active_run_data.get("negative_count", 0)),
			"positive_count": int(active_run_data.get("positive_count", 0)),
			"category": str(active_run_data.get("category", ""))
		}

	_setup_level_resource(run_payload)

	# Extraer items guardados (legacy: pueden estar anidados en mechanic_state o en la raíz)
	var saved_mechanic_state: Dictionary = saved_level_state
	if saved_level_state.get("mechanic_state", null) is Dictionary:
		var mechanic_dict: Dictionary = saved_level_state["mechanic_state"]
		if not mechanic_dict.is_empty():
			saved_mechanic_state = mechanic_dict

	var saved_items: Array = []
	if saved_mechanic_state.get("items", null) is Array:
		saved_items = saved_mechanic_state["items"]

	if _try_restore_saved_items(saved_items):
		layout_runtime_items()
		_place_saved_items_on_plate(saved_mechanic_state)
		return

	_spawn_fresh_items(run_payload)
	level_items.shuffle()
	layout_runtime_items()


func _setup_level_resource(run_payload: Dictionary) -> void:
	level_resource.mechanic_type = active_mechanic_type
	level_resource.mechanic_payload = run_payload
	level_resource.cantidadNegativos = int(run_payload.get("negative_count", 0))
	level_resource.cantidadPositivos = int(run_payload.get("positive_count", 0))
	level_resource.comida = GameChapterAssetCatalogScript.resolve_texture(
		active_run_data.get("meal_texture_path", "")
	)
	level_resource.condicion = GameChapterAssetCatalogScript.resolve_texture(
		active_run_data.get("condition_texture_path", "")
	)
	level_resource.ensenanza = GameChapterAssetCatalogScript.resolve_texture(
		active_run_data.get("teaching_texture_path", "")
	)
	meal_sprite.texture = level_resource.comida
	condition_sprite.texture = level_resource.condicion
	teaching_sprite.texture = level_resource.ensenanza


func _connect_scene_nodes(level_scene: Node) -> bool:
	if not is_instance_valid(plato):
		plato = level_scene.get_node_or_null("Plato")
	meal_sprite = level_scene.get_node_or_null("Globo texto/Meal") as Sprite2D
	condition_sprite = level_scene.get_node_or_null("Globo texto/Condition") as Sprite2D
	teaching_sprite = level_scene.get_node_or_null("Ensenanza") as Sprite2D

	var all_connected := (
		is_instance_valid(plato)
		and is_instance_valid(meal_sprite)
		and is_instance_valid(condition_sprite)
		and is_instance_valid(teaching_sprite)
	)
	if not all_connected:
		push_error("ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual.")
	return all_connected


func _spawn_fresh_items(run_payload: Dictionary) -> void:
	var category_code: String = str(run_payload.get("category", ""))

	var item_pools: Dictionary = GameTrackItemPoolCatalogScript.build_item_pool_for_track(
		active_track_key,
		level_resource.itemsPositivos,
		level_resource.itemsNegativos
	)

	var positive_items: Array = filter_items_by_category(
		item_pools.get("positive_items", []),
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
		item_pools.get("negative_items", []),
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


func _try_restore_saved_items(saved_item_entries: Array) -> bool:
	if saved_item_entries.is_empty():
		return false

	for raw_saved_item in saved_item_entries:
		if not _spawn_saved_item(raw_saved_item):
			clear_runtime_items()
			return false

	return not level_items.is_empty()


func _place_saved_items_on_plate(saved_mechanic_state: Dictionary) -> void:
	var raw_saved_positive_item_ids: Variant = saved_mechanic_state.get("placed_item_ids", [])
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


func _spawn_saved_item(raw_saved_item: Variant) -> bool:
	if not raw_saved_item is Dictionary:
		return false

	var saved_item: Dictionary = raw_saved_item
	var item_path: String = str(saved_item.get("item_path", "")).strip_edges()
	var instance_id: String = str(saved_item.get("instance_id", "")).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false

	var level_item = load(item_path)
	if level_item == null:
		return false

	var is_positive: bool = bool(saved_item.get("is_positive", false))
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
	if level_resource is Resource:
		return

	var resolved_resource_path: String = level_resource_path.strip_edges()
	if resolved_resource_path.is_empty():
		level_resource = LevelResourceScript.new()
		return

	var loaded_level_resource: Variant = load(resolved_resource_path)
	if loaded_level_resource is Resource:
		level_resource = loaded_level_resource
		return

	push_error(
		"ManagerLevel no pudo cargar level_resource en %s." % resolved_resource_path
	)
	level_resource = LevelResourceScript.new()
