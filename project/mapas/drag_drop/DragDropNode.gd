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
var _clave_nodo: String = ""
var _ruta_escena_de_retorno: String = DEFAULT_RETURN_SCENE_PATH
var _tiene_sesion_de_mapa: bool = false
var _actividad_completada: bool = false
var _mensaje_error_bloqueante: String = ""
var _titulo: String = ""
var _contenido: Dictionary = {}
var _targets_por_id: Dictionary = {}
var _ids_items_correctos: Array[String] = []
var _ids_items_colocados: Dictionary = {}

@onready var _label_titulo: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _label_instruccion: Label = $MarginContainer/PanelContainer/VBoxContainer/InstructionLabel
@onready var _contenedor_targets: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TargetsContainer
@onready var _grilla_items: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/ItemsGrid
@onready var _label_feedback: Label = $MarginContainer/PanelContainer/VBoxContainer/FeedbackLabel
@onready var _boton_continuar: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonsRow/ContinueButton


func _ready() -> void:
	_configurar_actividad_desde_sesion()
	if not _mensaje_error_bloqueante.is_empty():
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	_renderizar()


func configurar_desde_datos_nodo(datos_nodo: Dictionary, contexto_sesion: Dictionary) -> bool:
	_aplicar_contexto_sesion(contexto_sesion)
	if datos_nodo.is_empty():
		_mensaje_error_bloqueante = "El nodo drag_drop no recibio node_data normalizado."
		return false
	if str(datos_nodo.get("mode", "")).strip_edges() != DRAG_DROP_MODE:
		_mensaje_error_bloqueante = "La escena DragDropNode solo soporta mode drag_drop."
		return false

	_titulo = str(datos_nodo.get("title", "Nodo drag_drop")).strip_edges()
	_contenido = datos_nodo.get("content", {})
	_mensaje_error_bloqueante = _validar_contenido(_contenido)
	if not _mensaje_error_bloqueante.is_empty():
		return false

	_ids_items_correctos = _obtener_ids_items_correctos(_contenido.get("items", []))
	_ids_items_colocados.clear()
	_actividad_completada = false
	_boton_continuar.disabled = true
	return true


func _configurar_actividad_desde_sesion() -> void:
	_reiniciar_actividad()

	var contexto_sesion: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	if contexto_sesion.is_empty():
		_mensaje_error_bloqueante = "No hay una sesion activa para este nodo drag_drop."
		return

	var datos_nodo: Dictionary = _extraer_datos_nodo_de_sesion(contexto_sesion)
	configurar_desde_datos_nodo(datos_nodo, contexto_sesion)


func _aplicar_contexto_sesion(contexto_sesion: Dictionary) -> void:
	track_key = str(contexto_sesion.get("track_key", track_key)).strip_edges()
	_clave_nodo = str(contexto_sesion.get("node_key", "")).strip_edges()
	_ruta_escena_de_retorno = str(
		contexto_sesion.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _ruta_escena_de_retorno.is_empty():
		_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE_PATH
	_tiene_sesion_de_mapa = not contexto_sesion.is_empty()


func _extraer_datos_nodo_de_sesion(contexto_sesion: Dictionary) -> Dictionary:
	var datos_nodo: Variant = contexto_sesion.get("node_data", {})
	if datos_nodo is Dictionary:
		return (datos_nodo as Dictionary).duplicate(true)
	return {}


func _renderizar() -> void:
	_label_titulo.text = _titulo
	_label_instruccion.text = str(_contenido.get("instruction", "")).strip_edges()
	_mostrar_feedback(_label_instruccion.text, FEEDBACK_INFO_COLOR)
	_renderizar_targets(_contenido.get("targets", []))
	_renderizar_items(_contenido.get("items", []))


func _renderizar_targets(targets: Array) -> void:
	_limpiar_contenedor(_contenedor_targets)
	_targets_por_id.clear()

	for raw_target in targets:
		var datos_target: Dictionary = (raw_target as Dictionary).duplicate(true)
		var target_control: DragDropTarget = DragDropTargetScript.new()
		target_control.configurar(datos_target)
		target_control.item_dropped.connect(_manejar_drop)
		_contenedor_targets.add_child(target_control)
		_targets_por_id[str(datos_target.get("id", "")).strip_edges()] = target_control


func _renderizar_items(items: Array) -> void:
	_limpiar_contenedor(_grilla_items)

	for raw_item in items:
		var item_control: DragDropItem = DragDropItemScript.new()
		item_control.configurar((raw_item as Dictionary).duplicate(true))
		_grilla_items.add_child(item_control)


func _manejar_drop(target_id: String, datos_item: Dictionary) -> void:
	if _actividad_completada:
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
	return _targets_por_id.has(target_id) and not id_target_correcto.is_empty() and id_target_correcto == target_id


func _aceptar_item(target_id: String, item_node: DragDropItem, datos_item: Dictionary) -> void:
	var item_id: String = str(datos_item.get("item_id", "")).strip_edges()
	_ids_items_colocados[item_id] = true
	item_node.marcar_como_colocado()

	var target_control: DragDropTarget = _targets_por_id.get(target_id) as DragDropTarget
	if target_control != null:
		var ruta_textura: String = str(datos_item.get("image", "")).strip_edges()
		var textura: Texture2D = load(ruta_textura) as Texture2D if not ruta_textura.is_empty() else null
		target_control.agregar_item_colocado(
			str(datos_item.get("label", "")).strip_edges(),
			textura
		)

	_mostrar_feedback(
		_mensaje_de_contenido("success_message", "Bien! Ese item va en ese target."),
		FEEDBACK_SUCCESS_COLOR
	)
	_verificar_completado()


func _rechazar_item() -> void:
	_mostrar_feedback(
		_mensaje_de_contenido("error_message", "Ese item no corresponde a ese target."),
		FEEDBACK_ERROR_COLOR
	)


func _verificar_completado() -> void:
	if not _todos_colocados():
		return

	_actividad_completada = true
	_boton_continuar.disabled = false
	_mostrar_feedback(
		_mensaje_de_contenido("success_message", "Bien! Elegiste los items correctos."),
		FEEDBACK_SUCCESS_COLOR
	)


func _todos_colocados() -> bool:
	for item_id in _ids_items_correctos:
		if not bool(_ids_items_colocados.get(item_id, false)):
			return false
	return true


func _mostrar_error_bloqueante(mensaje: String) -> void:
	_label_titulo.text = "Contenido no disponible"
	_label_instruccion.text = mensaje
	_mostrar_feedback(mensaje, FEEDBACK_ERROR_COLOR)
	_contenedor_targets.hide()
	_grilla_items.hide()
	_boton_continuar.disabled = true


func _mostrar_feedback(mensaje: String, color_feedback: Color) -> void:
	_label_feedback.text = mensaje.strip_edges()
	_label_feedback.modulate = color_feedback


func _mensaje_de_contenido(clave: String, fallback: String) -> String:
	var mensaje: String = str(_contenido.get(clave, "")).strip_edges()
	if mensaje.is_empty():
		return fallback
	return mensaje


func _validar_contenido(contenido: Dictionary) -> String:
	var ids_targets: Array[String] = []
	var error_targets: String = _validar_targets(contenido.get("targets", []), ids_targets)
	if not error_targets.is_empty():
		return error_targets

	return _validar_items(contenido.get("items", []), ids_targets)


func _validar_targets(targets: Array, ids_targets: Array[String]) -> String:
	for raw_target in targets:
		var id_target: String = str((raw_target as Dictionary).get("id", "")).strip_edges()
		if ids_targets.has(id_target):
			return "DragDrop: hay targets repetidos (%s)." % id_target
		ids_targets.append(id_target)
	return ""


func _validar_items(items: Array, ids_targets: Array[String]) -> String:
	var ids_items: Array[String] = []
	var hay_items_correctos: bool = false
	for raw_item in items:
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


func _obtener_ids_items_correctos(items: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_item in items:
		var datos_item: Dictionary = raw_item as Dictionary
		if str(datos_item.get("correct_target", "")).strip_edges().is_empty():
			continue
		ids.append(str(datos_item.get("id", "")).strip_edges())
	return ids


func _reiniciar_actividad() -> void:
	_clave_nodo = ""
	_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE_PATH
	_tiene_sesion_de_mapa = false
	_actividad_completada = false
	_mensaje_error_bloqueante = ""
	_titulo = ""
	_contenido = {}
	_targets_por_id.clear()
	_ids_items_correctos.clear()
	_ids_items_colocados.clear()


func _limpiar_contenedor(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _volver_al_mapa() -> void:
	if _actividad_completada:
		if _tiene_sesion_de_mapa and not _clave_nodo.is_empty():
			Global.marcar_nodo_jugable_completado(track_key, _clave_nodo)
		SaveManager.registrar_sesion_preguntas_completada(
			_ids_items_correctos.size(),
			_ids_items_correctos.size()
		)

	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_ruta_escena_de_retorno)


func _on_back_button_pressed() -> void:
	_volver_al_mapa()


func _on_continue_button_pressed() -> void:
	if not _actividad_completada:
		return
	_volver_al_mapa()
