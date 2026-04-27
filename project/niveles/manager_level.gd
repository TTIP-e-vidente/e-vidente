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
const PARTIAL_SAVE_UNIT_SINGULAR := "alimento correcto en el plato"
const PARTIAL_SAVE_UNIT_PLURAL := "alimentos correctos en el plato"

@export var level_resource: Resource = null
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
var active_positive_item_count: int = 0
var active_negative_item_count: int = 0
var active_category_code: String = ""


func iniciar_nivel_sesion(track_key: String, level_scene: Node) -> void:
	if not _conectar_escena_nodos(level_scene):
		return

	active_track_key = track_key.strip_edges()
	_asegurar_recurso_nivel_cargado()

	var saved_level_state: Dictionary = Global.obtener_parcial_nivel_estado(
		active_track_key, Global.current_level
	)
	active_run_index = clampi(
		int(saved_level_state.get("run_index", 1)),
		1,
		obtener_total_corridas()
	)
	_cargar_corrida_actual(saved_level_state)


func avanzar_a_siguiente_corrida() -> bool:
	if active_run_index >= obtener_total_corridas():
		return false
	active_run_index += 1
	_cargar_corrida_actual({"run_index": active_run_index})
	return true


func obtener_actual_corrida_indice() -> int:
	return active_run_index


func obtener_total_corridas() -> int:
	return max(1, Global.obtener_capitulo_corrida_cantidad(active_track_key, Global.current_level))


func establecer_tiempo_ejecucion_elementos_interactuable(enabled: bool) -> void:
	for runtime_item in level_items:
		if not is_instance_valid(runtime_item):
			continue
		if runtime_item.has_method("set_interaction_enabled"):
			runtime_item.set_interaction_enabled(enabled)


# Solo arma y devuelve el dict de estado parcial. No guarda nada.
func construir_parcial_nivel_estado() -> Dictionary:
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

		if bool(runtime_item.esPositivo) and plato.tiene_positivo_elemento(runtime_item):
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


func almacenar_parcial_nivel_estado(track_key: String) -> int:
	var partial_level_state: Dictionary = construir_parcial_nivel_estado()
	Global.establecer_parcial_nivel_estado(
		track_key,
		Global.current_level,
		partial_level_state
	)
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		return 0
	return obtener_positivo_elementos_in_plato_cantidad()


func formatear_parcial_guardar_progreso(saved_positive_count: int) -> String:
	if saved_positive_count <= 0:
		return "Capitulo %d listo para retomar" % Global.current_level
	var unit: String = PARTIAL_SAVE_UNIT_SINGULAR
	if saved_positive_count != 1:
		unit = PARTIAL_SAVE_UNIT_PLURAL
	return "%d %s" % [saved_positive_count, unit]


func obtener_actual_corrida_guardar_label() -> String:
	var total_runs: int = obtener_total_corridas()
	if total_runs <= 1:
		return ""
	return "Corrida %d de %d" % [active_run_index, total_runs]


func obtener_positivo_elementos_in_plato_cantidad() -> int:
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE or not is_instance_valid(plato):
		return 0
	return plato.cantAlimentosPos.size()


func tiene_completado_actual_corrida() -> bool:
	if not is_instance_valid(plato):
		return false
	if level_resource == null:
		return false
	return (
		int(level_resource.cantidadPositivos) == obtener_positivo_elementos_in_plato_cantidad()
		and plato.cantAlimentosNeg.is_empty()
	)


func filtrar_elementos_por_categoria(items: Array, category: String) -> Array:
	if category.strip_edges().is_empty():
		return items.duplicate()
	var wanted: String = GameTrackCatalog.normalizar_codigo_categoria(category)
	var result: Array = []
	for item in items:
		if GameTrackCatalog.categorias_coinciden(str(item.categoria), wanted):
			result.append(item)
	return result


func generar_nivel_elemento(level_item: Resource, instance_id: String, is_positive: bool) -> Node:
	var level_item_instance: Node = level_item.escena.instantiate()
	if level_item_instance == null:
		return null
	level_item_instance.setup(level_item, plato, is_positive, instance_id)
	add_child(level_item_instance)
	level_items.append(level_item_instance)
	return level_item_instance


func limpiar_tiempo_ejecucion_elementos() -> void:
	for item in level_items:
		if is_instance_valid(item):
			item.queue_free()
	level_items.clear()
	if not is_instance_valid(plato):
		return
	plato.elementos.clear()
	plato.cantAlimentosPos.clear()
	plato.cantAlimentosNeg.clear()


func distribuir_tiempo_ejecucion_elementos() -> void:
	var next_item_position := Vector2(230, 680)
	var total_items: int = (
		level_resource.cantidadNegativos + level_resource.cantidadPositivos
	)
	if total_items < 5:
		next_item_position = Vector2(420, 680)
	for item in level_items:
		item.set_home_position(next_item_position)
		next_item_position.x += 120



func _cargar_corrida_actual(saved_level_state: Dictionary) -> void:
	limpiar_tiempo_ejecucion_elementos()

	var level_number: int = Global.current_level
	active_run_data = Global.obtener_capitulo_corrida_definicion(
		active_track_key, level_number, active_run_index
	)
	if active_run_data.is_empty():
		active_run_data = {}
		active_mechanic_type = ""
		_limpiar_activo_corrida_carga()
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d corrida %d."
			% [active_track_key, level_number, active_run_index]
		)
		return

	active_mechanic_type = str(active_run_data.get("mechanic_type", "")).strip_edges()
	if active_mechanic_type.is_empty():
		active_mechanic_type = PLATE_SORT_MECHANIC_TYPE
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		_limpiar_activo_corrida_carga()
		push_error("ManagerLevel no soporta la mecanica '%s'." % active_mechanic_type)
		return

	_aplicar_activo_corrida_carga()
	_configurar_nivel_recurso()

	# Extraer items guardados (legacy: pueden estar anidados en mechanic_state o en la raíz)
	var saved_mechanic_state: Dictionary = saved_level_state
	if saved_level_state.get("mechanic_state", null) is Dictionary:
		var mechanic_dict: Dictionary = saved_level_state["mechanic_state"]
		if not mechanic_dict.is_empty():
			saved_mechanic_state = mechanic_dict

	var saved_items: Array = []
	if saved_mechanic_state.get("items", null) is Array:
		saved_items = saved_mechanic_state["items"]

	if _intentar_restaurar_guardado_elementos(saved_items):
		distribuir_tiempo_ejecucion_elementos()
		_colocar_guardado_elementos_on_plato(saved_mechanic_state)
		return

	_generar_frescos_elementos()
	level_items.shuffle()
	distribuir_tiempo_ejecucion_elementos()


func _aplicar_activo_corrida_carga() -> void:
	var run_payload: Dictionary = {}
	if active_run_data.get("mechanic_payload", null) is Dictionary:
		run_payload = active_run_data["mechanic_payload"]

	if not run_payload.is_empty():
		active_negative_item_count = int(run_payload.get("negative_count", 0))
		active_positive_item_count = int(run_payload.get("positive_count", 0))
		active_category_code = str(run_payload.get("category", "")).strip_edges()
		return

	active_negative_item_count = int(active_run_data.get("negative_count", 0))
	active_positive_item_count = int(active_run_data.get("positive_count", 0))
	active_category_code = str(active_run_data.get("category", "")).strip_edges()


func _configurar_nivel_recurso() -> void:
	level_resource.mechanic_type = active_mechanic_type
	level_resource.mechanic_payload = _construir_activo_corrida_carga()
	level_resource.cantidadNegativos = active_negative_item_count
	level_resource.cantidadPositivos = active_positive_item_count
	level_resource.comida = GameChapterAssetCatalogScript.resolver_textura(
		active_run_data.get("meal_texture_path", "")
	)
	level_resource.condicion = GameChapterAssetCatalogScript.resolver_textura(
		active_run_data.get("condition_texture_path", "")
	)
	level_resource.ensenanza = GameChapterAssetCatalogScript.resolver_textura(
		active_run_data.get("teaching_texture_path", "")
	)
	meal_sprite.texture = level_resource.comida
	condition_sprite.texture = level_resource.condicion
	teaching_sprite.texture = level_resource.ensenanza


func _conectar_escena_nodos(level_scene: Node) -> bool:
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
		push_error(
			"ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual."
		)
	return all_connected


func _generar_frescos_elementos() -> void:
	var item_pools: Dictionary = GameTrackItemPoolCatalogScript.construir_fondo_elemento_pista(
		active_track_key,
		level_resource.itemsPositivos,
		level_resource.itemsNegativos
	)

	var positive_items: Array = filtrar_elementos_por_categoria(
		item_pools.get("positive_items", []),
		active_category_code
	)
	positive_items.shuffle()
	for item_index in range(active_positive_item_count):
		if positive_items.is_empty():
			break
		var level_item = positive_items.pop_front()
		if level_item == null:
			continue
		generar_nivel_elemento(level_item, "positive_%d" % item_index, true)

	var negative_items: Array = filtrar_elementos_por_categoria(
		item_pools.get("negative_items", []),
		active_category_code
	)
	negative_items.shuffle()
	for item_index in range(active_negative_item_count):
		if negative_items.is_empty():
			break
		var level_item = negative_items.pop_front()
		if level_item == null:
			continue
		generar_nivel_elemento(level_item, "negative_%d" % item_index, false)


func _intentar_restaurar_guardado_elementos(saved_item_entries: Array) -> bool:
	if saved_item_entries.is_empty():
		return false

	for raw_saved_item in saved_item_entries:
		if not _generar_guardado_elemento(raw_saved_item):
			limpiar_tiempo_ejecucion_elementos()
			return false

	return not level_items.is_empty()


func _colocar_guardado_elementos_on_plato(saved_mechanic_state: Dictionary) -> void:
	var raw_saved_positive_item_ids: Variant = saved_mechanic_state.get("placed_item_ids", [])
	if not raw_saved_positive_item_ids is Array:
		return

	var runtime_positive_items: Array = []
	for raw_item_id in raw_saved_positive_item_ids:
		var instance_id: String = str(raw_item_id).strip_edges()
		if instance_id.is_empty():
			continue

		var runtime_item = _buscar_tiempo_ejecucion_elemento_por_instance_id(instance_id)
		if runtime_item == null or not runtime_item.esPositivo:
			continue

		runtime_positive_items.append(runtime_item)

	for item_index in range(runtime_positive_items.size()):
		var runtime_item = runtime_positive_items[item_index]
		runtime_item.restore_to_plate(
			_obtener_plato_posicion(item_index, runtime_positive_items.size())
		)
		plato.restaurar_positivo_elemento(runtime_item)


func _generar_guardado_elemento(raw_saved_item: Variant) -> bool:
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
	return generar_nivel_elemento(level_item, instance_id, is_positive) != null


func _buscar_tiempo_ejecucion_elemento_por_instance_id(instance_id: String) -> Node:
	for runtime_item in level_items:
		if not is_instance_valid(runtime_item):
			continue
		if str(runtime_item.save_instance_id) == instance_id:
			return runtime_item
	return null


func _obtener_plato_posicion(index: int, total_items: int) -> Vector2:
	var columns: int = clampi(total_items, 1, MAX_PLATE_COLUMNS)
	var row: int = floori(float(index) / float(columns))
	var column: int = index % columns
	var horizontal_origin: float = float(columns - 1) / 2.0
	var offset: Vector2 = Vector2(
		(float(column) - horizontal_origin) * PLATE_ITEM_COLUMN_SPACING,
		float(row) * PLATE_ITEM_ROW_SPACING + PLATE_ITEM_VERTICAL_OFFSET
	)
	return plato.global_position + offset


func _construir_activo_corrida_carga() -> Dictionary:
	return {
		"negative_count": active_negative_item_count,
		"positive_count": active_positive_item_count,
		"category": active_category_code
	}


func _limpiar_activo_corrida_carga() -> void:
	active_positive_item_count = 0
	active_negative_item_count = 0
	active_category_code = ""


func _asegurar_recurso_nivel_cargado() -> void:
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
