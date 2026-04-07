extends Node
class_name ManagerLevel

const PARTIAL_ITEM_PATH_KEY := "item_path"
const PARTIAL_INSTANCE_ID_KEY := "instance_id"
const PARTIAL_IS_POSITIVE_KEY := "is_positive"

@export var level_resource : LevelResource

@onready var plato: Plato = %Plato

var posicion:Vector2
var lista_items = []
@onready var condition: Sprite2D = $"../Globo texto/Condition"
@onready var meal: Sprite2D = $"../Globo texto/Meal"
@onready var ensenanza: Sprite2D = $"../Ensenanza"
var nivelActual
var current_track_key := ""

func setup(nivel):
	if not _ensure_level_references():
		return
	_clear_spawned_items()
	current_track_key = ""
	if nivel != null and nivel.has_method("_get_resume_track_key"):
		current_track_key = str(nivel._get_resume_track_key()).strip_edges()
	nivelActual = Global.items_segun_nivel(get_parent())
	
	level_resource.cantidadNegativos = nivelActual[Global.current_level][0]
	level_resource.cantidadPositivos = nivelActual[Global.current_level][1]
	level_resource.comida = Global.resolve_texture(nivelActual[Global.current_level][2])
	level_resource.condicion = Global.resolve_texture(nivelActual[Global.current_level][3])
	level_resource.ensenanza = Global.resolve_texture(nivelActual[Global.current_level][4])
	
	ensenanza.texture = level_resource.ensenanza
	meal.texture = level_resource.comida
	condition.texture = level_resource.condicion
	
	var saved_level_state := Global.get_partial_level_state(current_track_key, Global.current_level)
	if not _spawn_items_from_saved_state(saved_level_state):
		items_aleatorios()
		lista_items.shuffle()
	_layout_items()
	_restore_saved_positive_items(saved_level_state)
	

func build_partial_save_state() -> Dictionary:
	var items: Array = []
	var placed_item_ids: Array = []
	for item in lista_items:
		if not is_instance_valid(item):
			continue
		var item_path := str(item.item_resource_path).strip_edges()
		var instance_id := str(item.save_instance_id).strip_edges()
		if item_path.is_empty() or instance_id.is_empty():
			continue
		items.append({
			PARTIAL_ITEM_PATH_KEY: item_path,
			PARTIAL_INSTANCE_ID_KEY: instance_id,
			PARTIAL_IS_POSITIVE_KEY: bool(item.esPositivo)
		})
		if item.esPositivo and plato.has_positive_item(item):
			placed_item_ids.append(instance_id)
	if items.is_empty():
		return {}
	return {
		Global.PARTIAL_LEVEL_ITEMS_KEY: items,
		Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: placed_item_ids
	}


func store_partial_level_state(track_key: String) -> Dictionary:
	var partial_state := build_partial_save_state()
	Global.set_partial_level_state(track_key, Global.current_level, partial_state)
	var placed_item_ids = partial_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	return {
		"placed_positive_count": placed_item_ids.size() if placed_item_ids is Array else 0,
		"has_partial_state": not partial_state.is_empty()
	}


func get_positive_items_in_plate_count() -> int:
	return plato.cantAlimentosPos.keys().size()


func _layout_items() -> void:
	if (level_resource.cantidadNegativos + level_resource.cantidadPositivos) < 5 :
		posicion = Vector2(420,680) 
	else:
		posicion = Vector2(230,680)
	for i in lista_items:
		i.set_home_position(posicion)
		posicion.x += 120
	

func items_aleatorios():
	var listaNegativos = level_resource.itemsNegativos.duplicate()
	var listaPositivos = level_resource.itemsPositivos.duplicate()
	listaNegativos.shuffle()
	listaPositivos.shuffle()
	
	var filtradosPositivos = Global.item_categoria(listaPositivos, nivelActual[Global.current_level][5])
	var filtradosNegativos = Global.item_categoria(listaNegativos, nivelActual[Global.current_level][5])
	
	for c in range(level_resource.cantidadPositivos):
		var level_item = filtradosPositivos.pop_front()
		_instantiate_level_item(level_item, "positive_%d" % c, true)
	for c in range(level_resource.cantidadNegativos):
		var level_item = filtradosNegativos.pop_front()
		_instantiate_level_item(level_item, "negative_%d" % c, false)


func _spawn_items_from_saved_state(saved_level_state: Dictionary) -> bool:
	var raw_items = saved_level_state.get(Global.PARTIAL_LEVEL_ITEMS_KEY, [])
	if not raw_items is Array or raw_items.is_empty():
		return false
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			_clear_spawned_items()
			return false
		var item_path := str(raw_item.get(PARTIAL_ITEM_PATH_KEY, "")).strip_edges()
		var instance_id := str(raw_item.get(PARTIAL_INSTANCE_ID_KEY, "")).strip_edges()
		var is_positive := bool(raw_item.get(PARTIAL_IS_POSITIVE_KEY, false))
		var level_item := load(item_path) as LevelItem
		if level_item == null or instance_id.is_empty():
			_clear_spawned_items()
			return false
		if _instantiate_level_item(level_item, instance_id, is_positive) == null:
			_clear_spawned_items()
			return false
	return not lista_items.is_empty()


func _instantiate_level_item(level_item: LevelItem, instance_id: String, is_positive: bool):
	var new_item = level_item.escena.instantiate()
	if new_item == null:
		return null
	new_item.setup(level_item, plato, is_positive, instance_id)
	add_child(new_item)
	lista_items.append(new_item)
	return new_item


func _restore_saved_positive_items(saved_level_state: Dictionary) -> void:
	var raw_placed_item_ids = saved_level_state.get(Global.PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	if not raw_placed_item_ids is Array or raw_placed_item_ids.is_empty():
		return
	var items_in_plate: Array = []
	for raw_item_id in raw_placed_item_ids:
		var item = _find_item_by_instance_id(str(raw_item_id).strip_edges())
		if item == null or not item.esPositivo:
			continue
		items_in_plate.append(item)
	for index in range(items_in_plate.size()):
		var item = items_in_plate[index]
		item.restore_to_plate(_plate_position_for_index(index, items_in_plate.size()))
		plato.restore_positive_item(item)


func _find_item_by_instance_id(instance_id: String):
	for item in lista_items:
		if not is_instance_valid(item):
			continue
		if str(item.save_instance_id) == instance_id:
			return item
	return null


func _plate_position_for_index(index: int, total_items: int) -> Vector2:
	var columns: int = total_items
	if columns < 1:
		columns = 1
	elif columns > 3:
		columns = 3
	var row: int = int(index / columns)
	var column: int = index % columns
	var horizontal_origin := float(columns - 1) / 2.0
	var offset := Vector2((float(column) - horizontal_origin) * 78.0, float(row) * 48.0 - 12.0)
	return plato.global_position + offset


func _clear_spawned_items() -> void:
	for item in lista_items:
		if is_instance_valid(item):
			item.queue_free()
	lista_items = []
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
	if not is_instance_valid(meal):
		meal = level_root.get_node_or_null("Globo texto/Meal") as Sprite2D
	if not is_instance_valid(condition):
		condition = level_root.get_node_or_null("Globo texto/Condition") as Sprite2D
	if not is_instance_valid(ensenanza):
		ensenanza = level_root.get_node_or_null("Ensenanza") as Sprite2D
	if not is_instance_valid(plato) or not is_instance_valid(meal) or not is_instance_valid(condition) or not is_instance_valid(ensenanza):
		push_error("ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual.")
		return false
	return true
