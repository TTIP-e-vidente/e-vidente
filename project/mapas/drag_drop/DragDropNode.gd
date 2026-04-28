extends Control

# Responsabilidad:
# - Recibir `node_data`, leer `content` y validar la actividad.
# - Renderizar `drag_drop`, recibir drops y actualizar progreso.
# - Finalizar y volver al mapa.
# No hace:
# - No define la UI detallada de item o target.
# - No valida `drag_drop` inline.
# - No decide que escena abrir.

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DragDropItemScript := preload("res://mapas/drag_drop/DragDropItem.gd")
const DragDropTargetScript := preload("res://mapas/drag_drop/DragDropTarget.gd")
const DragDropValidatorScript := preload("res://mapas/drag_drop/DragDropValidator.gd")

const DEFAULT_RETURN_SCENE_PATH := GameSceneRouter.MAP_SCENE_PATH
const DRAG_DROP_MODE := "drag_drop"

const FEEDBACK_INFO_COLOR := Color.WHITE
const FEEDBACK_SUCCESS_COLOR := Color(0.23, 0.72, 0.32)
const FEEDBACK_ERROR_COLOR := Color(0.82, 0.26, 0.26)

var track_key: String = "celiaquia"
var _active_question_key: String = ""
var _has_map_session: bool = false
var _return_scene_path: String = DEFAULT_RETURN_SCENE_PATH
var _activity_completed: bool = false
var _blocking_error_message: String = ""
var _node_data: Dictionary = {}
var _content: Dictionary = {}
var _target_controls_by_id: Dictionary = {}
var _required_item_ids: Array[String] = []
var _placed_item_ids: Dictionary = {}

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
	_renderizar_actividad()


func configurar_desde_datos_nodo(datos_nodo: Dictionary, session_context: Dictionary) -> bool:
	_aplicar_contexto_de_sesion(session_context)
	if datos_nodo.is_empty():
		_establecer_mensaje_de_error("El nodo drag_drop no recibio node_data normalizado.")
		return false
	if str(datos_nodo.get("mode", "")).strip_edges() != DRAG_DROP_MODE:
		_establecer_mensaje_de_error("La escena DragDropNode solo soporta mode drag_drop.")
		return false

	_node_data = datos_nodo.duplicate(true)
	_content = _node_data.get("content", {})
	return _validar_y_preparar_contenido()


func _configurar_desde_sesion_activa() -> void:
	_reiniciar_estado()

	var session_context: Dictionary = Global.obtener_activo_pregunta_sesion()
	if session_context.is_empty():
		_establecer_mensaje_de_error("No hay una sesion activa para este nodo drag_drop.")
		return

	var datos_nodo: Dictionary = _leer_datos_nodo_de_sesion(session_context)
	configurar_desde_datos_nodo(datos_nodo, session_context)


func _aplicar_contexto_de_sesion(session_context: Dictionary) -> void:
	track_key = str(session_context.get("track_key", track_key)).strip_edges()
	_active_question_key = str(session_context.get("question_key", "")).strip_edges()
	_return_scene_path = str(
		session_context.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = not session_context.is_empty()


func _validar_y_preparar_contenido() -> bool:
	var content_error: String = DragDropValidatorScript.validate_content(_content)
	if not content_error.is_empty():
		_establecer_mensaje_de_error(content_error)
		return false

	_required_item_ids = DragDropValidatorScript.get_required_item_ids(_content.get("items", []))
	_placed_item_ids.clear()
	_activity_completed = false
	_continue_button.disabled = true
	return true


func _renderizar_actividad() -> void:
	_renderizar_encabezado()
	_renderizar_targets()
	_renderizar_items()


func _renderizar_encabezado() -> void:
	_title_label.text = str(_node_data.get("title", "Nodo drag_drop")).strip_edges()
	_instruction_label.text = str(_content.get("instruction", "")).strip_edges()
	_mostrar_feedback(_instruction_label.text, FEEDBACK_INFO_COLOR)


func _renderizar_targets() -> void:
	_limpiar_contenedor(_targets_container)
	_target_controls_by_id.clear()

	var raw_targets: Array = _content.get("targets", [])
	for raw_target in raw_targets:
		var target_control: DragDropTarget = DragDropTargetScript.new()
		target_control.setup((raw_target as Dictionary).duplicate(true))
		target_control.item_dropped.connect(_manejar_item_soltado_en_target)
		_targets_container.add_child(target_control)
		var target_id: String = str(target_control.target_data.get("id", "")).strip_edges()
		_target_controls_by_id[target_id] = target_control


func _renderizar_items() -> void:
	_limpiar_contenedor(_items_grid)

	var raw_items: Array = _content.get("items", [])
	for raw_item in raw_items:
		var item_control: DragDropItem = DragDropItemScript.new()
		item_control.setup((raw_item as Dictionary).duplicate(true))
		_items_grid.add_child(item_control)


func _manejar_item_soltado_en_target(target_id: String, drag_data: Dictionary) -> void:
	if _activity_completed:
		return
	if not _target_controls_by_id.has(target_id):
		return

	var item_node: DragDropItem = drag_data.get("item_node") as DragDropItem
	if item_node == null:
		return
	if bool(item_node.item_data.get("placed", false)):
		return

	var correct_target: String = str(drag_data.get("correct_target", "")).strip_edges()
	if correct_target != target_id or correct_target.is_empty():
		_rechazar_drop()
		return

	_aceptar_drop_correcto(target_id, item_node, drag_data)


func _aceptar_drop_correcto(target_id: String, item_node: DragDropItem, drag_data: Dictionary) -> void:
	var item_id: String = str(drag_data.get("item_id", "")).strip_edges()
	_placed_item_ids[item_id] = true
	item_node.mark_as_placed()

	var target_control: DragDropTarget = _target_controls_by_id.get(target_id) as DragDropTarget
	if target_control != null:
		target_control.add_placed_item(
			str(drag_data.get("label", "")).strip_edges(),
			_cargar_textura_item(str(drag_data.get("image", "")).strip_edges())
		)

	_mostrar_feedback(_obtener_mensaje_de_exito(), FEEDBACK_SUCCESS_COLOR)
	_verificar_completado()


func _rechazar_drop() -> void:
	_mostrar_feedback(_obtener_mensaje_de_error(), FEEDBACK_ERROR_COLOR)


func _verificar_completado() -> void:
	for required_item_id in _required_item_ids:
		if not bool(_placed_item_ids.get(required_item_id, false)):
			return

	_activity_completed = true
	_continue_button.disabled = false
	_mostrar_feedback(_obtener_mensaje_de_exito(), FEEDBACK_SUCCESS_COLOR)


func _finalizar_actividad_si_corresponde() -> void:
	if not _activity_completed:
		return
	if _has_map_session and not _active_question_key.is_empty():
		Global.marcar_pregunta_completado(track_key, _active_question_key)
	SaveManager.registrar_sesion_preguntas_completada(_required_item_ids.size(), _required_item_ids.size())


func _finalizar_actividad_y_volver() -> void:
	Global.limpiar_activo_pregunta_sesion()
	get_tree().change_scene_to_file(_return_scene_path)


func _mostrar_error_bloqueante(message: String) -> void:
	_title_label.text = "Contenido no disponible"
	_instruction_label.text = message
	_mostrar_feedback(message, FEEDBACK_ERROR_COLOR)
	_targets_container.hide()
	_items_grid.hide()
	_continue_button.disabled = true


func _mostrar_feedback(message: String, feedback_color: Color) -> void:
	_feedback_label.text = message.strip_edges()
	_feedback_label.modulate = feedback_color


func _obtener_mensaje_de_exito() -> String:
	var success_message: String = str(_content.get("success_message", "")).strip_edges()
	if success_message.is_empty():
		return "Bien! Ese item va en ese target."
	return success_message


func _obtener_mensaje_de_error() -> String:
	var error_message: String = str(_content.get("error_message", "")).strip_edges()
	if error_message.is_empty():
		return "Ese item no corresponde a ese target."
	return error_message


func _cargar_textura_item(image_path: String) -> Texture2D:
	if image_path.is_empty():
		return null
	var resource: Variant = load(image_path)
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("DragDropNode: item image invalida (%s)." % image_path)
	return null


func _leer_datos_nodo_de_sesion(session_context: Dictionary) -> Dictionary:
	var raw_node_data: Variant = session_context.get("node_content", {})
	if raw_node_data is Dictionary:
		return (raw_node_data as Dictionary).duplicate(true)
	return {}


func _reiniciar_estado() -> void:
	_active_question_key = ""
	_has_map_session = false
	_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_activity_completed = false
	_blocking_error_message = ""
	_node_data = {}
	_content = {}
	_target_controls_by_id.clear()
	_required_item_ids.clear()
	_placed_item_ids.clear()


func _limpiar_contenedor(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _establecer_mensaje_de_error(message: String) -> void:
	var clean_message: String = message.strip_edges()
	if clean_message.is_empty():
		return
	if not _blocking_error_message.is_empty():
		return
	_blocking_error_message = clean_message


func _on_back_button_pressed() -> void:
	_finalizar_actividad_si_corresponde()
	_finalizar_actividad_y_volver()


func _on_continue_button_pressed() -> void:
	if not _activity_completed:
		return
	_finalizar_actividad_si_corresponde()
	_finalizar_actividad_y_volver()
