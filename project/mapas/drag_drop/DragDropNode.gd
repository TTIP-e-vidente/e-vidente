extends Control


const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DragDropItemScript := preload("res://mapas/drag_drop/DragDropItem.gd")
const DragDropTargetScript := preload("res://mapas/drag_drop/DragDropTarget.gd")

const DEFAULT_RETURN_SCENE_PATH := GameSceneRouter.MAP_SCENE_PATH
const DRAG_DROP_MODE := "drag_drop"

const FEEDBACK_INFO_COLOR := Color.WHITE
const FEEDBACK_SUCCESS_COLOR := Color(0.23, 0.72, 0.32)
const FEEDBACK_ERROR_COLOR := Color(0.82, 0.26, 0.26)

var track_key: String = "celiaquia"
var _node_key: String = ""
var _return_scene_path: String = DEFAULT_RETURN_SCENE_PATH
var _has_map_session: bool = false
var _activity_completed: bool = false
var _blocking_error_message: String = ""
var _title: String = ""
var _contenido: Dictionary = {}
var _targets: Dictionary = {}
var _ids_items_correctos: Array[String] = []
var _ids_items_colocados: Dictionary = {}

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _instruction_label: Label = $MarginContainer/PanelContainer/VBoxContainer/InstructionLabel
@onready var _targets_container: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TargetsContainer
@onready var _items_grid: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/ItemsGrid
@onready var _feedback_label: Label = $MarginContainer/PanelContainer/VBoxContainer/FeedbackLabel
@onready var _continue_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonsRow/ContinueButton


func _ready() -> void:
	_configurar_desde_sesion_activa()
	if not _blocking_error_message.is_empty():
		_mostrar_error_bloqueante(_blocking_error_message)
		return
	_renderizar()


func configurar_desde_datos_nodo(datos_nodo: Dictionary, contexto_sesion: Dictionary) -> bool:
	_aplicar_contexto_sesion(contexto_sesion)
	if datos_nodo.is_empty():
		_blocking_error_message = "El nodo drag_drop no recibio node_data normalizado."
		return false
	if str(datos_nodo.get("mode", "")).strip_edges() != DRAG_DROP_MODE:
		_blocking_error_message = "La escena DragDropNode solo soporta mode drag_drop."
		return false

	_title = str(datos_nodo.get("title", "Nodo drag_drop")).strip_edges()
	_contenido = datos_nodo.get("content", {})
	_blocking_error_message = _validar_contenido(_contenido)
	if not _blocking_error_message.is_empty():
		return false

	_ids_items_correctos = _items_correctos(_contenido.get("items", []))
	_ids_items_colocados.clear()
	_activity_completed = false
	_continue_button.disabled = true
	return true


func _configurar_desde_sesion_activa() -> void:
	_reiniciar_estado()

	var contexto_sesion: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	if contexto_sesion.is_empty():
		_blocking_error_message = "No hay una sesion activa para este nodo drag_drop."
		return

	var datos_nodo: Dictionary = {}
	var datos_sesion: Variant = contexto_sesion.get("node_data", {})
	if datos_sesion is Dictionary:
		datos_nodo = (datos_sesion as Dictionary).duplicate(true)
	configurar_desde_datos_nodo(datos_nodo, contexto_sesion)


func _aplicar_contexto_sesion(contexto_sesion: Dictionary) -> void:
	track_key = str(contexto_sesion.get("track_key", track_key)).strip_edges()
	_node_key = str(contexto_sesion.get("node_key", "")).strip_edges()
	_return_scene_path = str(
		contexto_sesion.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = not contexto_sesion.is_empty()


func _renderizar() -> void:
	_title_label.text = _title
	_instruction_label.text = str(_contenido.get("instruction", "")).strip_edges()
	_mostrar_feedback(_instruction_label.text, FEEDBACK_INFO_COLOR)
	_renderizar_targets(_contenido.get("targets", []))
	_renderizar_items(_contenido.get("items", []))


func _renderizar_targets(targets: Array) -> void:
	_limpiar_contenedor(_targets_container)
	_targets.clear()

	for raw_target in targets:
		var datos_target: Dictionary = (raw_target as Dictionary).duplicate(true)
		var target_control: DragDropTarget = DragDropTargetScript.new()
		target_control.configurar(datos_target)
		target_control.item_dropped.connect(_manejar_drop)
		_targets_container.add_child(target_control)
		_targets[str(datos_target.get("id", "")).strip_edges()] = target_control


func _renderizar_items(items: Array) -> void:
	_limpiar_contenedor(_items_grid)

	for raw_item in items:
		var item_control: DragDropItem = DragDropItemScript.new()
		item_control.configurar((raw_item as Dictionary).duplicate(true))
		_items_grid.add_child(item_control)


func _manejar_drop(target_id: String, datos_item: Dictionary) -> void:
	if _activity_completed:
		return

	var item_node: DragDropItem = datos_item.get("item_node") as DragDropItem
	if item_node == null or bool(item_node.datos_item.get("placed", false)):
		return

	if _es_correcto(target_id, datos_item):
		_aceptar_item(target_id, item_node, datos_item)
		return

	_rechazar_item()


func _es_correcto(target_id: String, datos_item: Dictionary) -> bool:
	var id_target_correcto: String = str(datos_item.get("correct_target", "")).strip_edges()
	return _targets.has(target_id) and not id_target_correcto.is_empty() and id_target_correcto == target_id


func _aceptar_item(target_id: String, item_node: DragDropItem, datos_item: Dictionary) -> void:
	var item_id: String = str(datos_item.get("item_id", "")).strip_edges()
	_ids_items_colocados[item_id] = true
	item_node.marcar_como_colocado()

	var target_control: DragDropTarget = _targets.get(target_id) as DragDropTarget
	if target_control != null:
		var texture_path: String = str(datos_item.get("image", "")).strip_edges()
		var texture: Texture2D = load(texture_path) as Texture2D if not texture_path.is_empty() else null
		target_control.agregar_item_colocado(
			str(datos_item.get("label", "")).strip_edges(),
			texture
		)

	_mostrar_feedback(_mensaje("success_message", "Bien! Ese item va en ese target."), FEEDBACK_SUCCESS_COLOR)
	_verificar_completado()


func _rechazar_item() -> void:
	_mostrar_feedback(
		_mensaje("error_message", "Ese item no corresponde a ese target."),
		FEEDBACK_ERROR_COLOR
	)


func _verificar_completado() -> void:
	if not _todos_colocados():
		return

	_activity_completed = true
	_continue_button.disabled = false
	_mostrar_feedback(_mensaje("success_message", "Bien! Elegiste los items correctos."), FEEDBACK_SUCCESS_COLOR)


func _todos_colocados() -> bool:
	for item_id in _ids_items_correctos:
		if not bool(_ids_items_colocados.get(item_id, false)):
			return false
	return true


func _mostrar_error_bloqueante(mensaje: String) -> void:
	_title_label.text = "Contenido no disponible"
	_instruction_label.text = mensaje
	_mostrar_feedback(mensaje, FEEDBACK_ERROR_COLOR)
	_targets_container.hide()
	_items_grid.hide()
	_continue_button.disabled = true


func _mostrar_feedback(mensaje: String, color_feedback: Color) -> void:
	_feedback_label.text = mensaje.strip_edges()
	_feedback_label.modulate = color_feedback


func _mensaje(clave: String, fallback: String) -> String:
	var mensaje: String = str(_contenido.get(clave, "")).strip_edges()
	if mensaje.is_empty():
		return fallback
	return mensaje


func _validar_contenido(content: Dictionary) -> String:
	var ids_targets: Array[String] = []
	for raw_target in content.get("targets", []):
		var id_target: String = str((raw_target as Dictionary).get("id", "")).strip_edges()
		if ids_targets.has(id_target):
			return "DragDrop: hay targets repetidos (%s)." % id_target
		ids_targets.append(id_target)

	var ids_items: Array[String] = []
	var hay_items_correctos: bool = false
	for raw_item in content.get("items", []):
		var datos_item: Dictionary = raw_item as Dictionary
		var id_item: String = str(datos_item.get("id", "")).strip_edges()
		if ids_items.has(id_item):
			return "DragDrop: hay items repetidos (%s)." % id_item
		ids_items.append(id_item)

		var id_target_correcto: String = str(datos_item.get("correct_target", "")).strip_edges()
		if id_target_correcto.is_empty():
			continue
		hay_items_correctos = true
		if not ids_targets.has(id_target_correcto):
			return "DragDrop: el item %s apunta a un target inexistente (%s)." % [id_item, id_target_correcto]

	if not hay_items_correctos:
		return "DragDrop: no hay items correctos para completar la actividad."

	return ""


func _items_correctos(items: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_item in items:
		var datos_item: Dictionary = raw_item as Dictionary
		if str(datos_item.get("correct_target", "")).strip_edges().is_empty():
			continue
		ids.append(str(datos_item.get("id", "")).strip_edges())
	return ids


func _reiniciar_estado() -> void:
	_node_key = ""
	_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = false
	_activity_completed = false
	_blocking_error_message = ""
	_title = ""
	_contenido = {}
	_targets.clear()
	_ids_items_correctos.clear()
	_ids_items_colocados.clear()


func _limpiar_contenedor(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _volver() -> void:
	if _activity_completed:
		if _has_map_session and not _node_key.is_empty():
			Global.marcar_nodo_jugable_completado(track_key, _node_key)
		SaveManager.registrar_sesion_preguntas_completada(
			_ids_items_correctos.size(),
			_ids_items_correctos.size()
		)

	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_return_scene_path)


func _on_back_button_pressed() -> void:
	_volver()


func _on_continue_button_pressed() -> void:
	if not _activity_completed:
		return
	_volver()
