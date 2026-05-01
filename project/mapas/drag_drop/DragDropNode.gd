extends Control


const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DragDropItemScript := preload("res://mapas/drag_drop/DragDropItem.gd")
const DragDropTargetScript := preload("res://mapas/drag_drop/DragDropTarget.gd")

const DEFAULT_RETURN_SCENE := GameSceneRouter.MAP_SCENE_PATH
const DRAG_DROP_MODE := "drag_drop"
const TITULO_POR_PISTA := {
	"celiaquia": "res://assets-sistema/interfaz/titulo-celiaquia.png",
	"veganismo": "res://assets-sistema/interfaz/titulo-veganismo.png",
	"veganismo_celiaquia": "res://assets-sistema/interfaz/titulo-celiaquia-veganismo.png",
	"keto": "res://assets-sistema/interfaz/titulo_keto.png"
}
const PERSONAJE_POR_PISTA := {
	"celiaquia": "res://assets-sistema/player/personaje-idle-1.png",
	"veganismo": "res://assets-sistema/player/player - vegan/personaje-idle-1.png",
	"veganismo_celiaquia": (
		"res://assets-sistema/player/player - vegan gluten free/personaje-idle-1.png"
	),
	"keto": "res://assets-sistema/player/player-keto/personaje-idle-1.png"
}

const FEEDBACK_INFO_COLOR := Color.WHITE
const FEEDBACK_SUCCESS_COLOR := Color(0.23, 0.72, 0.32)
const FEEDBACK_ERROR_COLOR := Color(0.82, 0.26, 0.26)

var track_key: String = "celiaquia"
var _clave_nodo: String = ""
var _ruta_escena_de_retorno: String = DEFAULT_RETURN_SCENE
var _tiene_sesion_de_mapa: bool = false
var _actividad_completada: bool = false
var _mensaje_error_bloqueante: String = ""
var _titulo: String = ""
var _contenido: Dictionary = {}
var _targets_por_id: Dictionary = {}
var _ids_items_correctos: Array[String] = []
var _ids_items_colocados: Dictionary = {}
var _progreso_guardado: bool = false
var ya_continuo: bool = false
var tiempo_restante: int = 5

@onready var _titulo_nivel_sprite: Sprite2D = $TituloNivel
@onready var _personaje_ilustracion: Sprite2D = $PlayerCambiante
@onready var _label_titulo: Label = $TitleLabel
@onready var _label_objetivo: Label = $ObjetivoLabel
@onready var _label_instruccion: Label = $InstructionLabel
@onready var _contenedor_targets: Control = $TargetsContainer
@onready var _contenedor_items: HFlowContainer = $ItemsContainer
@onready var _label_feedback: Label = $FeedbackLabel
@onready var _boton_volver: Button = $FlechaIzquierda
@onready var _boton_continuar: Button = $FlechaDerecha
@onready var _contador_siguiente_label: Label = $ContadorSiguienteLabel
@onready var _timer_siguiente_nodo: Timer = $TimerSiguienteNodo


func _ready() -> void:
	_ocultar_continuacion()
	_configurar_actividad_desde_sesion()
	if not _mensaje_error_bloqueante.is_empty():
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	renderizar()


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
	_mensaje_error_bloqueante = ""

	_ids_items_correctos = _obtener_ids_items_correctos(_contenido.get("items", []))
	_ids_items_colocados.clear()
	_actividad_completada = false
	_boton_continuar.disabled = true
	_boton_continuar.hide()
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
	_ruta_escena_de_retorno = GameSceneRouter.read_return_to(
		contexto_sesion,
		DEFAULT_RETURN_SCENE
	)
	if _ruta_escena_de_retorno.is_empty():
		_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE
	_tiene_sesion_de_mapa = not contexto_sesion.is_empty()


func _extraer_datos_nodo_de_sesion(contexto_sesion: Dictionary) -> Dictionary:
	var datos_nodo: Variant = contexto_sesion.get("node_data", {})
	if datos_nodo is Dictionary:
		return (datos_nodo as Dictionary).duplicate(true)
	return {}


func renderizar() -> void:
	mostrar_tema()
	_contenedor_targets.mouse_filter = Control.MOUSE_FILTER_PASS
	mostrar_consigna()
	_mostrar_feedback("", FEEDBACK_INFO_COLOR)
	configurar_plato()
	cargar_targets(_contenido.get("targets", []))
	cargar_items(_contenido.get("items", []))


func cargar_targets(targets: Array) -> void:
	_limpiar_contenedor(_contenedor_targets)
	_targets_por_id.clear()

	for raw_target in targets:
		var datos_target: Dictionary = (raw_target as Dictionary).duplicate(true)
		var target_control: DragDropTarget = crear_target(datos_target)
		_contenedor_targets.add_child(target_control)
		_targets_por_id[str(datos_target.get("id", "")).strip_edges()] = target_control


func cargar_items(items: Array) -> void:
	_limpiar_contenedor(_contenedor_items)

	for raw_item in items:
		var item_control: DragDropItem = crear_item_visual((raw_item as Dictionary).duplicate(true))
		_contenedor_items.add_child(item_control)


func crear_target(datos_target: Dictionary) -> DragDropTarget:
	var target_control: DragDropTarget = DragDropTargetScript.new()
	target_control.configurar(datos_target)
	target_control.item_dropped.connect(manejar_drop)
	target_control.anchor_right = 1.0
	target_control.anchor_bottom = 1.0
	target_control.offset_left = 0.0
	target_control.offset_top = 0.0
	target_control.offset_right = 0.0
	target_control.offset_bottom = 0.0
	return target_control


func crear_item_visual(datos_item: Dictionary) -> DragDropItem:
	var item_control: DragDropItem = DragDropItemScript.new()
	item_control.configurar(datos_item)
	return item_control


func manejar_drop(target_id: String, datos_item: Dictionary) -> void:
	if _actividad_completada:
		return

	var item_node: DragDropItem = datos_item.get("item_node") as DragDropItem
	if item_node == null or bool(item_node.datos_item.get("placed", false)):
		return

	if _es_correcto(target_id, datos_item):
		aceptar_item(target_id, item_node, datos_item)
		return

	rechazar_item()


func _es_correcto(target_id: String, datos_item: Dictionary) -> bool:
	var id_target_correcto: String = str(datos_item.get("correct_target", "")).strip_edges()
	return (
		_targets_por_id.has(target_id)
		and not id_target_correcto.is_empty()
		and id_target_correcto == target_id
	)


func aceptar_item(target_id: String, item_node: DragDropItem, datos_item: Dictionary) -> void:
	var item_id: String = str(datos_item.get("item_id", "")).strip_edges()
	_ids_items_colocados[item_id] = true
	item_node.marcar_como_colocado()

	var target_control: DragDropTarget = _targets_por_id.get(target_id) as DragDropTarget
	if target_control != null:
		var ruta_textura: String = str(datos_item.get("image", "")).strip_edges()
		var textura: Texture2D = (
			load(ruta_textura) as Texture2D if not ruta_textura.is_empty() else null
		)
		target_control.agregar_item_colocado(
			str(datos_item.get("label", "")).strip_edges(),
			textura
		)

	_mostrar_feedback(
		_mensaje_de_contenido("success_message", "Bien! Ese item va en ese target."),
		FEEDBACK_SUCCESS_COLOR
	)
	verificar_completado()


func rechazar_item() -> void:
	_mostrar_feedback(
		_mensaje_de_contenido("error_message", "Ese item no corresponde a ese target."),
		FEEDBACK_ERROR_COLOR
	)


func verificar_completado() -> void:
	if not _todos_colocados():
		return

	_actividad_completada = true
	_mostrar_feedback(
		_mensaje_de_contenido("success_message", "Bien! Elegiste los items correctos."),
		FEEDBACK_SUCCESS_COLOR
	)
	mostrar_ensenanza_final()


func _todos_colocados() -> bool:
	for item_id in _ids_items_correctos:
		if not bool(_ids_items_colocados.get(item_id, false)):
			return false
	return true


func _mostrar_error_bloqueante(mensaje: String) -> void:
	_label_titulo.text = "Contenido no disponible"
	_label_instruccion.text = mensaje
	_label_objetivo.text = "Objetivo"
	_mostrar_feedback(mensaje, FEEDBACK_ERROR_COLOR)
	_contenedor_targets.hide()
	_contenedor_items.hide()
	_boton_continuar.hide()
	_contador_siguiente_label.hide()


func _mostrar_feedback(mensaje: String, color_feedback: Color) -> void:
	_label_feedback.text = mensaje.strip_edges()
	_label_feedback.modulate = color_feedback
	_label_feedback.visible = not _label_feedback.text.is_empty()


func _obtener_texto_objetivo() -> String:
	var targets: Array = _contenido.get("targets", [])
	if targets.is_empty():
		return "Objetivo"

	var primer_target: Dictionary = targets[0] as Dictionary
	var texto_objetivo: String = str(primer_target.get("label", "")).strip_edges()
	if texto_objetivo.is_empty():
		return "Objetivo"
	return texto_objetivo


func _mensaje_de_contenido(clave: String, fallback: String) -> String:
	var mensaje: String = str(_contenido.get(clave, "")).strip_edges()
	if mensaje.is_empty():
		return fallback
	return mensaje


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
	_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE
	_tiene_sesion_de_mapa = false
	_actividad_completada = false
	_mensaje_error_bloqueante = ""
	_titulo = ""
	_contenido = {}
	_targets_por_id.clear()
	_ids_items_correctos.clear()
	_ids_items_colocados.clear()
	_progreso_guardado = false
	ya_continuo = false


func _limpiar_contenedor(contenedor: Node) -> void:
	for hijo in contenedor.get_children():
		hijo.queue_free()


func mostrar_tema() -> void:
	var ruta_titulo: String = str(TITULO_POR_PISTA.get(track_key, ""))
	if not ruta_titulo.is_empty():
		var textura_titulo: Texture2D = load(ruta_titulo) as Texture2D
		if textura_titulo != null:
			_titulo_nivel_sprite.texture = textura_titulo

	var ruta_personaje: String = str(PERSONAJE_POR_PISTA.get(track_key, ""))
	if not ruta_personaje.is_empty():
		var textura_personaje: Texture2D = load(ruta_personaje) as Texture2D
		if textura_personaje != null:
			_personaje_ilustracion.texture = textura_personaje


func mostrar_consigna() -> void:
	_label_titulo.text = _titulo
	_label_instruccion.text = str(_contenido.get("instruction", "")).strip_edges()
	_label_objetivo.text = _obtener_texto_objetivo()


func configurar_plato() -> void:
	# El target invisible vive encima del plato central y no altera su arte.
	_contenedor_targets.show()


func volver_al_mapa() -> void:
	_timer_siguiente_nodo.stop()
	if _actividad_completada and not _progreso_guardado:
		_progreso_guardado = true
		if _tiene_sesion_de_mapa and not _clave_nodo.is_empty():
			Global.marcar_nodo_jugable_completado(track_key, _clave_nodo)
		SaveManager.registrar_sesion_preguntas_completada(
			_ids_items_correctos.size(),
			_ids_items_correctos.size()
		)

	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_ruta_escena_de_retorno)


func mostrar_ensenanza_final() -> void:
	_guardar_progreso_si_no_guardado()
	mostrar_continuacion()


func mostrar_continuacion() -> void:
	tiempo_restante = 5
	ya_continuo = false
	_bloquear_drag_drop()
	_boton_volver.hide()
	_boton_continuar.show()
	_boton_continuar.disabled = false
	_contador_siguiente_label.show()
	_boton_continuar.move_to_front()
	_contador_siguiente_label.move_to_front()
	actualizar_texto_contador()
	iniciar_contador()


func iniciar_contador() -> void:
	_timer_siguiente_nodo.stop()
	_timer_siguiente_nodo.start()


func actualizar_texto_contador() -> void:
	_contador_siguiente_label.text = "Pr\u00f3ximo juego en %ds..." % tiempo_restante


func _ocultar_continuacion() -> void:
	_contenedor_targets.mouse_filter = Control.MOUSE_FILTER_PASS
	_boton_volver.show()
	_boton_continuar.hide()
	_boton_continuar.disabled = true
	_contador_siguiente_label.hide()


func _bloquear_drag_drop() -> void:
	for item in _contenedor_items.get_children():
		var item_drag: DragDropItem = item as DragDropItem
		if item_drag == null:
			continue
		item_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_contenedor_targets.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_timer_siguiente_nodo_timeout() -> void:
	if ya_continuo or not is_inside_tree():
		_timer_siguiente_nodo.stop()
		return

	tiempo_restante -= 1
	if tiempo_restante <= 0:
		_timer_siguiente_nodo.stop()
		continuar_al_siguiente_nodo()
		return

	actualizar_texto_contador()


func continuar_al_siguiente_nodo() -> void:
	if ya_continuo:
		return

	ya_continuo = true
	_timer_siguiente_nodo.stop()
	_guardar_progreso_si_no_guardado()

	if _clave_nodo.is_empty():
		volver_al_mapa()
		return

	Global.solicitar_continuar(_clave_nodo)
	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_ruta_escena_de_retorno)


func _guardar_progreso_si_no_guardado() -> void:
	if _progreso_guardado:
		return
	if not _actividad_completada:
		return
	_progreso_guardado = true
	if _tiene_sesion_de_mapa and not _clave_nodo.is_empty():
		Global.marcar_nodo_jugable_completado(track_key, _clave_nodo)
	SaveManager.registrar_sesion_preguntas_completada(
		_ids_items_correctos.size(),
		_ids_items_correctos.size()
	)


func _on_back_button_pressed() -> void:
	volver_al_mapa()


func _on_continue_button_pressed() -> void:
	if not _actividad_completada:
		return
	continuar_al_siguiente_nodo()
