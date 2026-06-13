extends Node2D


const GameStreakTrackerScript := preload("res://niveles/progress/GameStreakTracker.gd")
const PostGameFlowControllerScript := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)
const ContextoSesionDeJuegoScript := preload(
	"res://niveles/progress/ContextoSesionDeJuego.gd"
)
const ContextoFinalizacionDeJuegoScript := preload(
	"res://niveles/progress/ContextoFinalizacionDeJuego.gd"
)
const ContinuidadDePartidaDeNodoScript := preload(
	"res://mapas/logica/ContinuidadDePartidaDeNodo.gd"
)
const NodoRuntimeScript := preload("res://sistemas/NodoRuntime.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const ResultadoDeMiniJuegoScript := preload("res://modalidades/ResultadoDeMiniJuego.gd")
const PresentadorContinuarJuegoScript := preload(
	"res://interface/components/ContinuarJuego/PresentadorContinuarJuego.gd"
)
const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const PresentadorEnsenanzasScript := preload("res://ensenanzas/PresentadorEnsenanzas.gd")
const ConceptItemScene := preload("res://vincular/concept_item.tscn")
const LOG_PREFIX_MATCH := "[Match]"

const CLAVE_PISTA_PREDETERMINADA := "celiaquia"
const ESCENA_RETORNO_PREDETERMINADA := "res://mapas/MapScene.tscn"
const BADGE_TEXTURE := preload("res://assets-sistema/interfaz/pregunta-1.png")
const COLOR_TARJETA_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TARJETA_SELECCIONADA := Color(0.93, 1.0, 0.95, 1.0)
const COLOR_TARJETA_VINCULADA := Color(0.97, 1.0, 0.98, 1.0)
const COLOR_TARJETA_ERROR := Color(1.0, 0.94, 0.94, 1.0)
const COLOR_LINEA_OK := Color(0.2, 0.62, 0.38, 1.0)
const COLOR_LINEA_ERROR := Color(0.92, 0.22, 0.2, 1.0)
const COLOR_LINEA_SOMBRA := Color(0.05, 0.04, 0.03, 0.28)
const COLOR_GUIA := Color(0.26, 0.47, 0.37, 1.0)
const TEXTO_GUIA_INICIAL := "Primero elegi un concepto de la izquierda."
const TEXTO_GUIA_CON_SELECCION := "Ahora elegi su pareja de la derecha."
const TEXTO_GUIA_CON_SELECCION_DERECHA := "Ahora elegi su pareja de la izquierda."
const TEXTO_GUIA_GENERAL := "Elegi una tarjeta de la izquierda y despues su pareja de la derecha."
const TEXTO_GUIA_CORRECTO := "Bien. Esa relacion es correcta."
const TEXTO_GUIA_ERROR := "Proba otra combinacion."
const MARGEN_ANCLAJE_LINEA := 12.0
const DURACION_ANIMACION_LINEA := 0.16
const MAX_HISTORIAL_PATRONES := 3
const MAX_INTENTOS_MEZCLA := 8

@onready var label_pregunta: Label = $Control/LabelPregunta
@onready var titulo_nivel: Label = $TituloNivel/Label
@onready var contenedor_izquierda: VBoxContainer = $Control/VBoxIzquierda
@onready var contenedor_derecha: VBoxContainer = $Control/VBoxDerecha
@onready var control_principal: Control = $Control
@onready var line_drawer: Line2D = $Control/LineDrawer
@onready var boton_atras: Button = $"Atrás"
@onready var indicador_de_progreso_de_juego = $IndicadorProgresoDeJuego
@onready var _progress_bar = get_node_or_null("ProgressBar")
@onready var _continuar_juego = $ContinuarJuego

var items_izquierda: Array[ConceptoItem] = []
var items_derecha: Array[ConceptoItem] = []
var seleccion_actual: ConceptoItem = null
var seleccion_derecha_pendiente: ConceptoItem = null

var total_pares := 0
var _pares_vinculados_correctos: int = 0
var _pares_vinculados_total: int = 0
var clave_pista := CLAVE_PISTA_PREDETERMINADA
var nivel_id := 1
var bloqueado := false
var ya_continuo := false
var validado := false
var boton_confirmar: Button = null
var boton_continuar_validacion: Button = null
var feedback_label: Label = null
var guide_label: Label = null
var _feedback_tween: Tween
var _guia_tween: Tween
var center_hint: PanelContainer = null
var click_areas: Control = null
var teaching_sprite: Sprite2D = null

var _nodo_actual: String = ""
var _tiene_sesion_de_mapa := false
var _pertenece_a_partida_de_nodo := false
var _ruta_escena_de_retorno := ESCENA_RETORNO_PREDETERMINADA
var _mensaje_error_bloqueante := ""
var _retroalimentacion_racha_post_juego: Dictionary = {}
var _estado_flujo_post_juego: Dictionary = {}
var _datos_de_ejecucion: Dictionary = {}
var _continuar_juego_es_continuacion_pendiente := false
var _continuar_juego_es_validacion_pendiente := false
var _activity_started_msec: int = 0
var finalizacion_enviada: bool = false

static var _historial_patrones_de_ronda: Array[String] = []


func _ready() -> void:
	_activity_started_msec = Time.get_ticks_msec()
	print("[TimeTracker] started activity_id=", str(_datos_de_ejecucion.get("id", "")))
	_preparar_sprite_ensenanza()
	_preparar_layout_ui()
	_recolectar_items()
	_preparar_controles_de_confirmacion()
	_preparar_click_areas()
	_acomodar_pantalla()
	if line_drawer != null:
		line_drawer.z_as_relative = false
		line_drawer.z_index = 10
		line_drawer.show()
	_conectar_continuar_juego()
	if boton_atras != null:
		boton_atras.pressed.connect(_on_atras_presionado)
	configurar_desde_sesion()
	_configurar_indicador_de_progreso_de_juego()
	if not _mensaje_error_bloqueante.is_empty():
		if _mostrar_continuacion_pendiente_si_corresponde():
			return
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	_aplicar_runtime_en_escena()


func _recolectar_items() -> void:
	items_izquierda = _extraer_conceptos(contenedor_izquierda)
	items_derecha = _extraer_conceptos(contenedor_derecha)


func _extraer_conceptos(contenedor: VBoxContainer) -> Array[ConceptoItem]:
	var items: Array[ConceptoItem] = []
	for child in contenedor.get_children():
		var item: ConceptoItem = child as ConceptoItem
		if item == null:
			continue
		if not item.seleccionado.is_connected(_on_item_seleccionado):
			item.seleccionado.connect(_on_item_seleccionado)
		items.append(item)
	return items


func _conectar_continuar_juego() -> void:
	if _continuar_juego == null:
		return
	# El componente vive bajo un Node2D: los anchors no resuelven contra el viewport,
	# asi que forzamos posicion absoluta para que la flecha sea visible.
	_continuar_juego.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_continuar_juego.offset_left = 0.0
	_continuar_juego.offset_top = 0.0
	_continuar_juego.offset_right = 0.0
	_continuar_juego.offset_bottom = 0.0
	_continuar_juego.position = Vector2(960.0, 632.0)
	_continuar_juego.size = Vector2(128.0, 128.0)
	_continuar_juego.z_as_relative = false
	_continuar_juego.z_index = 250
	if _continuar_juego.has_signal("continuar_solicitado"):
		_continuar_juego.connect(
			"continuar_solicitado",
			Callable(self, "_al_solicitar_continuar_juego")
		)


func _preparar_layout_ui() -> void:
	control_principal.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_principal.offset_left = 0
	control_principal.offset_top = 0
	control_principal.offset_right = 0
	control_principal.offset_bottom = 0
	control_principal.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if line_drawer != null:
		line_drawer.z_as_relative = false
		line_drawer.z_index = 10
		line_drawer.show()

	if is_instance_valid(titulo_nivel):
		titulo_nivel.text = "Celiaquía"


func _asegurar_margin_container(nombre: String, parent: Node) -> MarginContainer:
	var node := parent.get_node_or_null(nombre) as MarginContainer
	if node == null:
		node = MarginContainer.new()
		node.name = nombre
		parent.add_child(node)
	return node


func _asegurar_vbox(nombre: String, parent: Node) -> VBoxContainer:
	var node := parent.get_node_or_null(nombre) as VBoxContainer
	if node == null:
		node = VBoxContainer.new()
		node.name = nombre
		parent.add_child(node)
	return node


func _asegurar_hbox(nombre: String, parent: Node) -> HBoxContainer:
	var node := parent.get_node_or_null(nombre) as HBoxContainer
	if node == null:
		node = HBoxContainer.new()
		node.name = nombre
		parent.add_child(node)
	return node


func _asegurar_hint_card(parent: Node) -> PanelContainer:
	var node := parent.get_node_or_null("CenterHint") as PanelContainer
	if node == null:
		node = PanelContainer.new()
		node.name = "CenterHint"
		parent.add_child(node)
		var padding := MarginContainer.new()
		padding.name = "Padding"
		node.add_child(padding)
		_set_margenes(padding, 18, 14, 18, 14)
		guide_label = Label.new()
		guide_label.name = "GuideLabel"
		padding.add_child(guide_label)
	else:
		guide_label = node.get_node_or_null("Padding/GuideLabel") as Label
	node.custom_minimum_size = Vector2(248, 128)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.add_theme_stylebox_override("panel", _crear_estilo_hint())
	if guide_label != null:
		guide_label.custom_minimum_size = Vector2(210, 90)
		guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		guide_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide_label.add_theme_font_size_override("font_size", 22)
		guide_label.add_theme_color_override("font_color", COLOR_GUIA)
		guide_label.text = TEXTO_GUIA_GENERAL
	return node


func _ordenar_hijos_main_layout(
	main_layout: HBoxContainer,
	left_column: VBoxContainer,
	hint: PanelContainer,
	right_column: VBoxContainer
) -> void:
	main_layout.move_child(left_column, 0)
	main_layout.move_child(hint, 1)
	main_layout.move_child(right_column, 2)


func _configurar_columna(columna: VBoxContainer) -> void:
	columna.custom_minimum_size = Vector2(282, 0)
	columna.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	columna.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 0)


func _reparent_control(node: Control, nuevo_parent: Node) -> void:
	if node == null or node.get_parent() == nuevo_parent:
		return
	node.get_parent().remove_child(node)
	nuevo_parent.add_child(node)


func _reparent_canvas_item(node: CanvasItem, nuevo_parent: Node) -> void:
	if node == null or node.get_parent() == nuevo_parent:
		return
	node.get_parent().remove_child(node)
	nuevo_parent.add_child(node)


func _set_margenes(
	node: MarginContainer,
	left: int,
	top: int,
	right: int,
	bottom: int
) -> void:
	node.add_theme_constant_override("margin_left", left)
	node.add_theme_constant_override("margin_top", top)
	node.add_theme_constant_override("margin_right", right)
	node.add_theme_constant_override("margin_bottom", bottom)


func _crear_estilo_hint() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1, 0.86)
	estilo.border_color = Color(0.26, 0.47, 0.37, 0.55)
	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2
	estilo.corner_radius_top_left = 8
	estilo.corner_radius_top_right = 8
	estilo.corner_radius_bottom_right = 8
	estilo.corner_radius_bottom_left = 8
	return estilo


func _mostrar_continuacion_pendiente_si_corresponde() -> bool:
	if _continuar_juego == null:
		return false
	if not _datos_de_ejecucion.is_empty():
		return false
	if not Global.hay_juego_o_nodo_para_continuar():
		return false
	_continuar_juego_es_continuacion_pendiente = true
	bloqueado = true
	label_pregunta.text = ""
	_actualizar_texto_guia("")
	_limpiar_vinculos_y_errores()
	_actualizar_visual()
	_bloquear_tarjetas()
	_continuar_juego.call("mostrar_para_continuar_pendiente")
	return true


func configurar_desde_sesion() -> void:
	_reiniciar_estado_local()
	var contexto_sesion: Dictionary = ContextoSesionDeJuegoScript.obtener_contexto_jugable_actual()
	if contexto_sesion.is_empty():
		_mensaje_error_bloqueante = "No hay una sesión activa para este juego."
		return
	var contexto_normalizado: Dictionary = ContextoSesionDeJuegoScript.normalizar_contexto_jugable(
		contexto_sesion,
		clave_pista,
		nivel_id,
		ESCENA_RETORNO_PREDETERMINADA
	)
	_aplicar_contexto_de_sesion(contexto_normalizado)
	_cargar_datos_de_vinculacion(contexto_normalizado)


func _aplicar_contexto_de_sesion(contexto_sesion: Dictionary) -> void:
	clave_pista = ContextoSesionDeJuegoScript.leer_track_key(contexto_sesion, clave_pista)
	nivel_id = ContextoSesionDeJuegoScript.leer_nivel_id(contexto_sesion, nivel_id)
	_nodo_actual = ContextoSesionDeJuegoScript.leer_node_key(contexto_sesion)
	_pertenece_a_partida_de_nodo = (
		ContextoSesionDeJuegoScript.leer_pertenece_a_nodo(contexto_sesion))
	_ruta_escena_de_retorno = ContextoSesionDeJuegoScript.leer_return_to(
		contexto_sesion, ESCENA_RETORNO_PREDETERMINADA)
	_tiene_sesion_de_mapa = ContextoSesionDeJuegoScript.leer_came_from_map(contexto_sesion)


func _cargar_datos_de_vinculacion(contexto_sesion: Dictionary) -> void:
	var activity_id: String = str(contexto_sesion.get("activity_id", "")).strip_edges()
	var ruta_json: String = str(contexto_sesion.get("json_path", "")).strip_edges()
	if activity_id.is_empty() and ruta_json.is_empty():
		_mensaje_error_bloqueante = "Falta activity_id o json_path para la vinculacion."
		return

	var resultado_nodo: Dictionary = NodeContentLoaderScript.cargar_desde_contexto(contexto_sesion)
	if not bool(resultado_nodo.get("ok", false)):
		_mensaje_error_bloqueante = str(
			resultado_nodo.get("error", "No se pudo cargar el contenido de vinculación.")
		)
		return

	var resultado_runtime: Dictionary = (
		NodeContentLoaderScript.convertir_vinculacion_a_runtime(
			resultado_nodo.get("data", {})
		)
	)
	if not bool(resultado_runtime.get("ok", false)):
		_mensaje_error_bloqueante = str(
			resultado_runtime.get("error", "No se pudo preparar la vinculación.")
		)
		return

	_datos_de_ejecucion = resultado_runtime.get("data", {}).duplicate(true)
	print(
		LOG_PREFIX_MATCH,
		" activity=",
		str(_datos_de_ejecucion.get("id", _nodo_actual)),
		" pairs=",
		int((_datos_de_ejecucion.get("conceptos_izquierda", []) as Array).size())
	)


func _reiniciar_estado_local() -> void:
	seleccion_actual = null
	total_pares = 0
	_pares_vinculados_correctos = 0
	_pares_vinculados_total = 0
	bloqueado = false
	ya_continuo = false
	validado = false
	_nodo_actual = ""
	_tiene_sesion_de_mapa = false
	_pertenece_a_partida_de_nodo = false
	_ruta_escena_de_retorno = ESCENA_RETORNO_PREDETERMINADA
	_mensaje_error_bloqueante = ""
	_retroalimentacion_racha_post_juego = {}
	_estado_flujo_post_juego = {}
	_datos_de_ejecucion = {}
	_continuar_juego_es_continuacion_pendiente = false
	_continuar_juego_es_validacion_pendiente = false
	_limpiar_vinculos_y_errores()


func _limpiar_vinculos_y_errores() -> void:
	seleccion_actual = null
	seleccion_derecha_pendiente = null
	for item in _todos_los_items():
		item.limpiar_vinculo()


func _preparar_controles_de_confirmacion() -> void:
	boton_confirmar = control_principal.get_node_or_null("ConfirmButton") as Button
	if boton_confirmar == null:
		boton_confirmar = Button.new()
		boton_confirmar.name = "ConfirmButton"
		control_principal.add_child(boton_confirmar)
	boton_confirmar.offset_left = 456.0
	boton_confirmar.offset_top = 728.0
	boton_confirmar.offset_right = 700.0
	boton_confirmar.offset_bottom = 784.0
	boton_confirmar.text = "Confirmar"
	boton_confirmar.visible = false
	boton_confirmar.disabled = true
	boton_confirmar.z_index = 110
	_aplicar_estilo_boton_badge(boton_confirmar, 22)
	if not boton_confirmar.pressed.is_connected(confirmar):
		boton_confirmar.pressed.connect(confirmar)

	_preparar_feedback_label()


func _preparar_boton_continuar_validacion() -> void:
	boton_continuar_validacion = control_principal.get_node_or_null("ContinueButton") as Button
	if boton_continuar_validacion == null:
		boton_continuar_validacion = Button.new()
		boton_continuar_validacion.name = "ContinueButton"
		control_principal.add_child(boton_continuar_validacion)
	boton_continuar_validacion.offset_left = 456.0
	boton_continuar_validacion.offset_top = 736.0
	boton_continuar_validacion.offset_right = 700.0
	boton_continuar_validacion.offset_bottom = 794.0
	boton_continuar_validacion.text = "Continuar"
	boton_continuar_validacion.visible = false
	boton_continuar_validacion.disabled = true
	boton_continuar_validacion.z_index = 111
	_aplicar_estilo_boton_badge(boton_continuar_validacion, 24)
	if not boton_continuar_validacion.pressed.is_connected(_on_continuar_presionado):
		boton_continuar_validacion.pressed.connect(_on_continuar_presionado)


func _preparar_feedback_label() -> void:
	feedback_label = control_principal.get_node_or_null("FeedbackLabel") as Label
	if feedback_label == null:
		feedback_label = Label.new()
		feedback_label.name = "FeedbackLabel"
		control_principal.add_child(feedback_label)
	feedback_label.offset_left = 180.0
	feedback_label.offset_top = 668.0
	feedback_label.offset_right = 976.0
	feedback_label.offset_bottom = 716.0
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 22)
	feedback_label.add_theme_color_override("font_color", MiPaleta.FEEDBACK_NEUTRAL)
	feedback_label.visible = true
	feedback_label.z_index = 20
	feedback_label.text = ""
	# Una sola guia: guide_label apunta al mismo nodo que feedback_label
	guide_label = feedback_label


func _obtener_feedback_layer() -> VBoxContainer:
	var feedback_layer := control_principal.get_node_or_null(
		"ScreenMargin/ScreenStack/FeedbackLayer"
	) as VBoxContainer
	if feedback_layer == null:
		feedback_layer = _asegurar_vbox("FeedbackLayer", control_principal)
	return feedback_layer


func _aplicar_estilo_boton_badge(boton: Button, font_size: int) -> void:
	var estilo := _crear_estilo_badge()
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_font_size_override("font_size", font_size)
	boton.add_theme_color_override("font_color", Color.WHITE)
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)
	boton.add_theme_color_override("font_focus_color", Color.WHITE)
	boton.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	boton.add_theme_stylebox_override("normal", estilo)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("pressed", estilo)
	boton.add_theme_stylebox_override("focus", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)


func _crear_estilo_badge() -> StyleBoxTexture:
	var estilo := StyleBoxTexture.new()
	estilo.texture = BADGE_TEXTURE
	estilo.content_margin_left = 32.0
	estilo.content_margin_top = 14.0
	estilo.content_margin_right = 32.0
	estilo.content_margin_bottom = 14.0
	return estilo


func _acomodar_pantalla() -> void:
	label_pregunta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_pregunta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contenedor_izquierda.custom_minimum_size = Vector2(282, 0)
	contenedor_derecha.custom_minimum_size = Vector2(282, 0)


func _preparar_click_areas() -> void:
	click_areas = control_principal.get_node_or_null("ClickAreas") as Control
	if click_areas == null:
		click_areas = Control.new()
		click_areas.name = "ClickAreas"
		control_principal.add_child(click_areas)
	click_areas.visible = false
	click_areas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_areas.z_index = 100


func _limpiar_click_areas() -> void:
	if click_areas == null:
		return
	for child in click_areas.get_children():
		click_areas.remove_child(child)
		child.queue_free()


func _configurar_indicador_de_progreso_de_juego() -> void:
	# Ocultar el badge "Juego X/Y" — la barra inferior es el único indicador de progreso
	if indicador_de_progreso_de_juego != null:
		indicador_de_progreso_de_juego.hide()
	# Actualizar barra inferior con la posición actual dentro del nodo
	if _progress_bar == null:
		return
	var contexto: Dictionary = ContextoSesionDeJuegoScript.obtener_modelo_indicador_actual()
	var actual: int = int(contexto.get("actual", 1))
	var total: int = int(contexto.get("total", 1))
	if _progress_bar.has_method("actualizar_progreso"):
		_progress_bar.actualizar_progreso(actual, total)


func _aplicar_runtime_en_escena() -> void:
	titulo_nivel.text = "Celiaquía"
	label_pregunta.text = str(
		_datos_de_ejecucion.get("instruccion", "Relacioná correctamente")
	).strip_edges()

	var conceptos_izquierda: Array = _datos_de_ejecucion.get("conceptos_izquierda", [])
	var conceptos_derecha: Array = _datos_de_ejecucion.get("conceptos_derecha", [])
	total_pares = mini(conceptos_izquierda.size(), conceptos_derecha.size())
	if total_pares <= 0:
		_mostrar_error_bloqueante("La vinculación no tiene pares suficientes.")
		return
	_asegurar_slots_visuales(total_pares)
	if total_pares > items_izquierda.size() or total_pares > items_derecha.size():
		_mostrar_error_bloqueante(
			"La escena de vinculación no tiene suficientes tarjetas visuales."
		)
		return

	validado = false
	_ocultar_continuar()
	_limpiar_click_areas()
	_limpiar_vinculos_y_errores()

	var ronda := _construir_ronda_mezclada(conceptos_izquierda, conceptos_derecha)
	var conceptos_izquierda_mezclados: Array = ronda.get("izquierda", [])
	var conceptos_derecha_mezclados: Array = ronda.get("derecha", [])
	_crear_tarjetas(conceptos_izquierda_mezclados, conceptos_derecha_mezclados)
	_mostrar_feedback(TEXTO_GUIA_INICIAL)
	_actualizar_texto_guia(TEXTO_GUIA_INICIAL)
	_actualizar_visual()
	call_deferred("_sincronizar_layout_interactivo")


func _crear_tarjetas(conceptos_izquierda: Array, conceptos_derecha: Array) -> void:
	_configurar_lado(items_izquierda, conceptos_izquierda, "izquierda")
	_configurar_lado(items_derecha, conceptos_derecha, "derecha")


func _asegurar_slots_visuales(total_requerido: int) -> void:
	_asegurar_slots_en_contenedor(
		contenedor_izquierda,
		items_izquierda,
		total_requerido,
		"ConceptItemIzq"
	)
	_asegurar_slots_en_contenedor(
		contenedor_derecha,
		items_derecha,
		total_requerido,
		"ConceptItemDer"
	)
	_ajustar_layout_para_total_pares(total_requerido)


func _asegurar_slots_en_contenedor(
	contenedor: VBoxContainer,
	items_existentes: Array[ConceptoItem],
	total_requerido: int,
	prefijo_nombre: String
) -> void:
	if contenedor == null:
		return
	while items_existentes.size() < total_requerido:
		var nuevo_item := ConceptItemScene.instantiate() as ConceptoItem
		if nuevo_item == null:
			return
		nuevo_item.name = "%s%d" % [prefijo_nombre, items_existentes.size() + 1]
		nuevo_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		contenedor.add_child(nuevo_item)
		if not nuevo_item.seleccionado.is_connected(_on_item_seleccionado):
			nuevo_item.seleccionado.connect(_on_item_seleccionado)
		items_existentes.append(nuevo_item)


func _ajustar_layout_para_total_pares(total_requerido: int) -> void:
	var separacion := 28
	if total_requerido >= 5:
		separacion = 8
	elif total_requerido == 4:
		separacion = 18
	contenedor_izquierda.add_theme_constant_override("separation", separacion)
	contenedor_derecha.add_theme_constant_override("separation", separacion)


func _sincronizar_layout_interactivo() -> void:
	await get_tree().process_frame
	_actualizar_visual()


func _mezclar_columna(conceptos: Array) -> Array:
	var copia: Array = conceptos.duplicate(true)
	copia.shuffle()
	return copia


func _evitar_alineacion_por_fila(
	izquierda: Array,
	derecha: Array
) -> Array:
	# Si por azar quedó algún par correcto en la misma fila, intercambia esa
	# fila con otra para que la columna no luzca pre-alineada.
	var resultado: Array = derecha.duplicate(true)
	var total: int = mini(izquierda.size(), resultado.size())
	if total < 2:
		return resultado
	for fila in range(total):
		var par_izq := str((izquierda[fila] as Dictionary).get("id_par", "")).strip_edges()
		var par_der := str((resultado[fila] as Dictionary).get("id_par", "")).strip_edges()
		if par_izq.is_empty() or par_der.is_empty() or par_izq != par_der:
			continue
		var swap_idx := -1
		for otra in range(total):
			if otra == fila:
				continue
			var par_izq_otra := str((izquierda[otra] as Dictionary).get("id_par", "")).strip_edges()
			var par_der_otra := str((resultado[otra] as Dictionary).get("id_par", "")).strip_edges()
			# Buscamos una fila donde intercambiar no genere otra alineación.
			if par_der_otra != par_izq and par_der != par_izq_otra:
				swap_idx = otra
				break
		if swap_idx >= 0:
			var tmp = resultado[fila]
			resultado[fila] = resultado[swap_idx]
			resultado[swap_idx] = tmp
	return resultado


func _construir_ronda_mezclada(
	conceptos_iz: Array,
	conceptos_der: Array
) -> Dictionary:
	# Mezcla ambas columnas de forma independiente y evita repetir el mismo
	# patrón visual que se usó recientemente. Reintenta hasta MAX_INTENTOS_MEZCLA
	# veces antes de aceptar cualquier resultado.
	var izq := _mezclar_columna(conceptos_iz)
	var der := _evitar_alineacion_por_fila(izq, _mezclar_columna(conceptos_der))
	var intentos := 0
	while intentos < MAX_INTENTOS_MEZCLA:
		var firma := construir_firma_patron(izq, der)
		if not _historial_patrones_de_ronda.has(firma):
			_registrar_patron(firma)
			break
		izq = _mezclar_columna(conceptos_iz)
		der = _evitar_alineacion_por_fila(izq, _mezclar_columna(conceptos_der))
		intentos += 1
	print(
		"[MatchShuffle] left_order=%s right_order=%s"
		% [_unir_ids_para_log(izq), _unir_ids_para_log(der)]
	)
	return {"izquierda": izq, "derecha": der}


## Construye una firma legible del patrón visual actual a partir del orden de
## id_par en cada columna. Firmas idénticas indican disposiciones idénticas.
## Función pública y estática para facilitar tests sin escena.
static func construir_firma_patron(izquierda: Array, derecha: Array) -> String:
	var ids_izq: Array[String] = []
	var ids_der: Array[String] = []
	for item in izquierda:
		var d: Dictionary = item as Dictionary
		ids_izq.append(str(d.get("id_par", d.get("id", ""))))
	for item in derecha:
		var d: Dictionary = item as Dictionary
		ids_der.append(str(d.get("id_par", d.get("id", ""))))
	return "|L:%s|R:%s" % [",".join(ids_izq), ",".join(ids_der)]


func _registrar_patron(firma: String) -> void:
	_historial_patrones_de_ronda.push_back(firma)
	while _historial_patrones_de_ronda.size() > MAX_HISTORIAL_PATRONES:
		_historial_patrones_de_ronda.pop_front()


func _unir_ids_para_log(conceptos: Array) -> String:
	var ids: Array[String] = []
	for c in conceptos:
		var d: Dictionary = c as Dictionary
		var id_str := str(d.get("id", d.get("id_par", "")))
		ids.append(id_str)
	return ",".join(ids)


func _ordenar_derecha_para_evitar_cruces(
	conceptos_izquierda: Array,
	conceptos_derecha: Array
) -> Array:
	var ordenados: Array = []
	var usadas: Array[String] = []

	for concepto_izquierda in conceptos_izquierda:
		var datos_izquierda: Dictionary = concepto_izquierda as Dictionary
		var par_izquierda := str(datos_izquierda.get("id_par", "")).strip_edges()
		for concepto_derecha in conceptos_derecha:
			var datos_derecha: Dictionary = concepto_derecha as Dictionary
			var id_derecha := str(datos_derecha.get("id", "")).strip_edges()
			var par_derecha := str(datos_derecha.get("id_par", "")).strip_edges()
			if not usadas.has(id_derecha) and par_derecha == par_izquierda:
				ordenados.append(datos_derecha)
				usadas.append(id_derecha)
				break

	for concepto_derecha in conceptos_derecha:
		var datos_derecha: Dictionary = concepto_derecha as Dictionary
		var id_derecha := str(datos_derecha.get("id", "")).strip_edges()
		if not usadas.has(id_derecha):
			ordenados.append(datos_derecha)

	return ordenados


func _configurar_lado(items_escena: Array[ConceptoItem], conceptos: Array, lado: String) -> void:
	# Contrato principal: texto visible + id_par compartido.
	# ActivityAdapter mantiene text/par_key solo como compatibilidad legacy.
	for indice in range(items_escena.size()):
		var item := items_escena[indice]
		if indice >= conceptos.size():
			item.ocultar_y_bloquear()
			continue

		var concepto: Dictionary = conceptos[indice] as Dictionary
		item.configurar_desde_diccionario(concepto, lado)
		_aplicar_estado_tarjeta(item, "normal")
		_hacer_tarjeta_clickeable(item)


func _hacer_tarjeta_clickeable(item: ConceptoItem) -> void:
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.focus_mode = Control.FOCUS_NONE


func _ignorar_mouse_en_hijos(node: Node) -> void:
	for child in node.get_children():
		var control_child: Control = child as Control
		if control_child != null:
			control_child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignorar_mouse_en_hijos(child)


func _crear_area_click_sobre_tarjeta(item: ConceptoItem) -> Button:
	var area := Button.new()
	area.name = "ClickArea_%s" % item.concept_id
	area.text = ""
	area.flat = true
	area.focus_mode = Control.FOCUS_NONE
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.self_modulate = Color(1, 1, 1, 0)
	area.set_meta("card", item)
	area.pressed.connect(Callable(self, "_on_item_seleccionado").bind(item))
	click_areas.add_child(area)
	_actualizar_rect_area_click(area)
	return area


func _actualizar_areas_click() -> void:
	if click_areas == null:
		return
	for child in click_areas.get_children():
		var area: Button = child as Button
		if area != null:
			_actualizar_rect_area_click(area)


func _actualizar_rect_area_click(area: Button) -> void:
	var card: Control = area.get_meta("card", null) as Control
	if not is_instance_valid(card):
		area.disabled = true
		return
	var rect := _obtener_rect_visual_tarjeta(card)
	area.global_position = rect.position
	area.size = rect.size
	area.disabled = bloqueado or validado


func _obtener_rect_visual_tarjeta(card: Control) -> Rect2:
	var rect := card.get_global_rect()
	if rect.size.x > 4.0 and rect.size.y > 4.0:
		return rect

	var sprite: Sprite2D = card.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture != null:
		var textura_size := sprite.texture.get_size()
		var escala := Vector2(abs(sprite.global_scale.x), abs(sprite.global_scale.y))
		var size := Vector2(textura_size.x * escala.x, textura_size.y * escala.y)
		return Rect2(sprite.global_position - size * 0.5, size)

	return Rect2(card.global_position, Vector2(160, 64))

func _on_item_seleccionado(item: ConceptoItem) -> void:
	if bloqueado or validado or item == null or item.bloqueado:
		return
	print("[MatchClick] item=", item.concept_id, " side=", item.lado, " id_par=", item.par_key)
	if item.es_izquierda():
		_seleccionar_tarjeta_izquierda(item)
	elif item.es_derecha():
		_seleccionar_tarjeta_derecha(item)


func seleccionar_izquierda(item: ConceptoItem) -> void:
	_seleccionar_tarjeta_izquierda(item)


func seleccionar_derecha(item: ConceptoItem) -> void:
	_seleccionar_tarjeta_derecha(item)


func _seleccionar_tarjeta_izquierda(item: ConceptoItem) -> void:
	print(LOG_PREFIX_MATCH, " selected_left=", item.concept_id)
	# Si ya había una tarjeta de la derecha pendiente (selección inversa), confirmar el par.
	if seleccion_derecha_pendiente != null:
		seleccion_actual = item
		confirmar()
		return
	# WRONG → SELECTED: no limpiar el par completo al reseleccionar.
	# Solo marcar la tarjeta clickeada como seleccion_actual y limpiar su
	# feedback local; la otra tarjeta del par debe conservar su estado WRONG.
	if item.tiene_error:
		# Limpiar el feedback visual/metadata de error SOLO de esta tarjeta.
		item.marcar_error(false)
	seleccion_actual = item
	seleccion_derecha_pendiente = null
	_actualizar_texto_guia(TEXTO_GUIA_CON_SELECCION)
	_mostrar_feedback("Elegí una tarjeta de la derecha.")
	_actualizar_visual()


func vincular_con_derecha(derecha: ConceptoItem) -> void:
	# API publica usada por tests automatizados: vincula directo sin pasar por Confirmar.
	if seleccion_actual == null:
		return
	var izquierda := seleccion_actual
	quitar_vinculo_anterior_de(derecha)
	if izquierda.vinculada_con != null:
		izquierda.limpiar_vinculo()
	izquierda.vincular_con(derecha)
	seleccion_actual = null
	seleccion_derecha_pendiente = null
	validado = false
	_ocultar_continuar()
	_animar_vinculo_correcto(izquierda, derecha)
	_validar_par_actual(izquierda, derecha)
	_actualizar_visual()


func _seleccionar_tarjeta_derecha(derecha: ConceptoItem) -> void:
	if seleccion_actual == null:
		# Permitir selección derecha-primero: almacenar y esperar la izquierda.
		# Si la tarjeta derecha estaba en WRONG, limpiar solo su feedback local
		# para que el jugador pueda reintentar desde ese extremo sin resetear
		# todo el par.
		if derecha.tiene_error:
			derecha.marcar_error(false)
		seleccion_derecha_pendiente = derecha
		print(LOG_PREFIX_MATCH, " selected_right_first=", derecha.concept_id)
		_actualizar_texto_guia(TEXTO_GUIA_CON_SELECCION_DERECHA)
		_mostrar_feedback("Ahora elegí su pareja de la izquierda.")
		_actualizar_visual()
		return
	print(LOG_PREFIX_MATCH, " selected_right=", derecha.concept_id)
	seleccion_derecha_pendiente = derecha
	confirmar()


func quitar_vinculo_anterior_de(derecha: ConceptoItem) -> void:
	for izquierda in items_izquierda:
		if izquierda.visible and izquierda.vinculada_con == derecha:
			izquierda.limpiar_vinculo()
			return


func _validar_par_actual(izquierda: ConceptoItem, derecha: ConceptoItem) -> void:
	var correcto := _tarjetas_forman_par(izquierda, derecha)
	print(
		"[MatchValidate] left=", izquierda.concept_id,
		" right=", derecha.concept_id,
		" id_par_left=", izquierda.par_key,
		" id_par_right=", derecha.par_key,
		" correct=", correcto
	)
	_pares_vinculados_total += 1
	if correcto:
		_pares_vinculados_correctos += 1
	# Registrar resultado por par vinculado: cada intento de vinculacion cuenta
	Global.registrar_resultado_mini_juego(correcto)
	if correcto:
		_mostrar_feedback_correcto(izquierda)
		return
	_mostrar_feedback_error(izquierda, derecha)


func _tarjetas_forman_par(izquierda: ConceptoItem, derecha: ConceptoItem) -> bool:
	return (
		is_instance_valid(izquierda)
		and is_instance_valid(derecha)
		and izquierda.par_key == derecha.par_key
	)


func _mostrar_feedback_correcto(izquierda: ConceptoItem) -> void:
	# Limpiar estado de error en ambos extremos del par correcto.
	izquierda.marcar_error(false)
	if is_instance_valid(izquierda.vinculada_con):
		izquierda.vinculada_con.marcar_error(false)
	_mostrar_feedback(TEXTO_GUIA_CORRECTO, MiPaleta.FEEDBACK_OK)
	_actualizar_texto_guia(TEXTO_GUIA_INICIAL)
	print(LOG_PREFIX_MATCH, " correct pair=", izquierda.par_key)


func _mostrar_feedback_error(izquierda: ConceptoItem, derecha: ConceptoItem = null) -> void:
	# Marcar error en ambos extremos del par para que cada tarjeta tenga
	# su propio estado interno de WRONG. Esto permite que al reintentar
	# tocando solo una tarjeta, la otra permanezca marcada en error.
	izquierda.marcar_error(true)
	if derecha != null and is_instance_valid(derecha):
		derecha.marcar_error(true)
	_mostrar_feedback(TEXTO_GUIA_ERROR, MiPaleta.FEEDBACK_ERROR)
	_actualizar_texto_guia(TEXTO_GUIA_ERROR, MiPaleta.FEEDBACK_ERROR)


func _completar_vinculacion() -> void:
	_mostrar_feedback("Excelente. Completaste las relaciones.", MiPaleta.FEEDBACK_OK)
	_actualizar_texto_guia("Excelente. Completaste las relaciones.", MiPaleta.FEEDBACK_OK)
	print(
		LOG_PREFIX_MATCH,
		" completed activity=",
		str(_datos_de_ejecucion.get("id", _nodo_actual))
	)


func _actualizar_visual() -> void:
	_actualizar_tarjetas()
	_actualizar_lineas()
	_actualizar_estado_confirmar()
	_actualizar_areas_click()


func _actualizar_tarjetas() -> void:
	# Primero, aplicar estado base a las tarjetas derechas según su propio estado.
	for derecha in items_derecha:
		if not derecha.visible:
			continue
		if derecha == seleccion_derecha_pendiente:
			_aplicar_estado_tarjeta(derecha, "seleccionada")
		elif derecha.tiene_error:
			_aplicar_estado_tarjeta(derecha, "error")
		else:
			_aplicar_estado_tarjeta(derecha, "normal")

	# Luego, aplicar estado a las tarjetas izquierdas y ajustar la derecha
	# vinculada sólo si no está en un estado de mayor prioridad.
	for izquierda in items_izquierda:
		if not izquierda.visible:
			continue
		if izquierda == seleccion_actual:
			_aplicar_estado_tarjeta(izquierda, "seleccionada")
		elif izquierda.tiene_error:
			_aplicar_estado_tarjeta(izquierda, "error")
		elif izquierda.esta_vinculada():
			_aplicar_estado_tarjeta(izquierda, "vinculada")
		else:
			_aplicar_estado_tarjeta(izquierda, "normal")

		if is_instance_valid(izquierda.vinculada_con) and izquierda.vinculada_con.visible:
			var d := izquierda.vinculada_con
			# Prioridad: seleccionada > error > vinculada > normal.
			if d == seleccion_derecha_pendiente:
				_aplicar_estado_tarjeta(d, "seleccionada")
			elif d.tiene_error:
				_aplicar_estado_tarjeta(d, "error")
			elif not d.tiene_error:
				_aplicar_estado_tarjeta(d, "vinculada")


func _aplicar_estado_tarjeta(item: Control, tipo: String) -> void:
	if item != null and item.has_method("aplicar_estado_visual"):
		item.call("aplicar_estado_visual", tipo)
		return
	match tipo:
		"seleccionada":
			item.modulate = COLOR_TARJETA_SELECCIONADA
		"vinculada":
			item.modulate = COLOR_TARJETA_VINCULADA
		"error":
			item.modulate = COLOR_TARJETA_ERROR
		_:
			item.modulate = COLOR_TARJETA_NORMAL


func _actualizar_estado_confirmar() -> void:
	if boton_confirmar == null:
		return
	boton_confirmar.visible = false
	boton_confirmar.disabled = true


func faltan_vinculos() -> bool:
	for izquierda in items_izquierda:
		if izquierda.visible and izquierda.vinculada_con == null:
			return true
	return false


func _mostrar_feedback(texto: String, color: Color = MiPaleta.FEEDBACK_NEUTRAL) -> void:
	if feedback_label == null:
		return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	feedback_label.text = texto
	feedback_label.modulate = Color(color.r, color.g, color.b, 0.0)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(feedback_label, "modulate", color, 0.25)


func _actualizar_texto_guia(texto: String, color: Color = MiPaleta.FEEDBACK_NEUTRAL) -> void:
	if guide_label == null:
		return
	if _guia_tween != null and _guia_tween.is_valid():
		_guia_tween.kill()
	guide_label.text = texto
	guide_label.modulate = color


func _animar_vinculo_correcto(izquierda: ConceptoItem, derecha: ConceptoItem) -> void:
	for tarjeta in [izquierda, derecha]:
		if tarjeta == null or not is_instance_valid(tarjeta):
			continue
		var escala_base: Vector2 = tarjeta.scale
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(tarjeta, "scale", escala_base * 1.06, 0.08)
		tween.tween_property(tarjeta, "scale", escala_base, 0.12)


func _actualizar_lineas() -> void:
	if line_drawer == null:
		return
	for child in line_drawer.get_children():
		line_drawer.remove_child(child)
		child.queue_free()

	for izquierda in items_izquierda:
		if izquierda.visible and izquierda.vinculada_con != null:
			_dibujar_linea_de_vinculo(izquierda)


func _dibujar_linea_de_vinculo(item_izquierda: ConceptoItem) -> void:
	var item_derecha := item_izquierda.vinculada_con
	if not is_instance_valid(item_izquierda) or not is_instance_valid(item_derecha):
		return

	# La linea se marca como error si cualquiera de los extremos está marcado como
	# error, de modo que si el jugador resetea sólo una tarjeta la otra siga
	# mostrando el estado WRONG y la linea permanezca roja.
	var color := COLOR_LINEA_ERROR if (
		item_izquierda.tiene_error or (is_instance_valid(item_derecha) and item_derecha.tiene_error)
	) else COLOR_LINEA_OK
	var origen: Vector2 = _obtener_ancla_derecha(item_izquierda)
	var destino: Vector2 = _obtener_ancla_izquierda(item_derecha)
	var debe_animar := item_izquierda.animar_vinculo
	_crear_linea(origen, destino, COLOR_LINEA_SOMBRA, 7.0, debe_animar)
	_crear_linea(origen, destino, color, 4.0, debe_animar)
	item_izquierda.animar_vinculo = false


func _obtener_ancla_derecha(card: Control) -> Vector2:
	var rect := _obtener_rect_visual_tarjeta(card)
	var punto_global := Vector2(
		rect.position.x + rect.size.x - MARGEN_ANCLAJE_LINEA,
		rect.position.y + rect.size.y * 0.5
	)
	return line_drawer.to_local(punto_global)


func _obtener_ancla_izquierda(card: Control) -> Vector2:
	var rect := _obtener_rect_visual_tarjeta(card)
	var punto_global := Vector2(
		rect.position.x + MARGEN_ANCLAJE_LINEA,
		rect.position.y + rect.size.y * 0.5
	)
	return line_drawer.to_local(punto_global)


func _crear_linea(
	origen: Vector2,
	destino: Vector2,
	color: Color,
	ancho: float,
	animar: bool = false
) -> void:
	var linea := Line2D.new()
	linea.width = ancho
	linea.default_color = color
	linea.points = PackedVector2Array([origen, origen if animar else destino])
	line_drawer.add_child(linea)
	if animar:
		_animar_linea(linea, origen, destino)


func _animar_linea(linea: Line2D, origen: Vector2, destino: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		linea,
		"points",
		PackedVector2Array([origen, destino]),
		DURACION_ANIMACION_LINEA
	)


func confirmar() -> void:
	if bloqueado or validado:
		return

	# Caso 1: hay un par pendiente desde clicks (izquierda + derecha) -> validar ese par.
	if seleccion_actual != null and seleccion_derecha_pendiente != null:
		var izquierda := seleccion_actual
		var derecha := seleccion_derecha_pendiente
		print("[MatchSelect] left=", izquierda.concept_id, " right=", derecha.concept_id)
		quitar_vinculo_anterior_de(derecha)
		if izquierda.vinculada_con != null:
			izquierda.limpiar_vinculo()
		izquierda.vincular_con(derecha)
		seleccion_actual = null
		seleccion_derecha_pendiente = null
		_animar_vinculo_correcto(izquierda, derecha)
		_validar_par_actual(izquierda, derecha)
		_actualizar_visual()
		if not faltan_vinculos():
			_finalizar_validacion_completa()
		return

	# Caso 2: ya estan todos los vinculos (por API de test) -> validar todo.
	if faltan_vinculos():
		_mostrar_feedback("Faltan relaciones por completar.", MiPaleta.FEEDBACK_ERROR)
		return
	_finalizar_validacion_completa()


func _finalizar_validacion_completa() -> void:
	var todo_bien := true
	for izquierda in items_izquierda:
		if not izquierda.visible:
			continue
		izquierda.marcar_error(not _tarjetas_forman_par(izquierda, izquierda.vinculada_con))
		if izquierda.tiene_error:
			todo_bien = false

	validado = todo_bien
	if todo_bien:
		print("[MatchComplete] activity=", str(_datos_de_ejecucion.get("id", _nodo_actual)))
		_completar_vinculacion()
		_mostrar_cierre_de_vinculacion()
		_actualizar_visual()
		return

	validado = false
	_ocultar_continuar()
	_mostrar_feedback("Revisá las relaciones marcadas.", MiPaleta.FEEDBACK_ERROR)
	_actualizar_visual()


func _mostrar_continuar() -> void:
	if _continuar_juego == null:
		print("[MatchContinue] show=false reason=null_node")
		return
	_continuar_juego_es_validacion_pendiente = true
	# Reposicionar por las dudas (si la escena cambio en runtime).
	_continuar_juego.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_continuar_juego.position = Vector2(960.0, 632.0)
	_continuar_juego.size = Vector2(128.0, 128.0)
	_continuar_juego.z_as_relative = false
	_continuar_juego.z_index = 250
	_continuar_juego.modulate = Color(1, 1, 1, 1)
	# Usar la version con temporizador para que la flecha se anime y, si el jugador no la ve,
	# avance solo despues de unos segundos.
	var hay_siguiente := _hay_siguiente_juego_de_partida()
	if _continuar_juego.has_method("mostrar_para_siguiente_juego") and hay_siguiente:
		_continuar_juego.call("mostrar_para_siguiente_juego", 5)
	elif _continuar_juego.has_method("mostrar_para_finalizar"):
		_continuar_juego.call("mostrar_para_finalizar", 5)
	elif _continuar_juego.has_method("mostrar_para_continuar_pendiente"):
		_continuar_juego.call("mostrar_para_continuar_pendiente")
	print(
		"[MatchContinue] show=true visible=", _continuar_juego.visible,
		" pos=", _continuar_juego.position,
		" hay_siguiente=", hay_siguiente
	)
	_set_click_areas_habilitadas(false)


func _ocultar_continuar() -> void:
	_continuar_juego_es_validacion_pendiente = false
	if _continuar_juego != null and _continuar_juego.has_method("ocultar"):
		_continuar_juego.call("ocultar")
	if not bloqueado:
		_set_click_areas_habilitadas(true)


func _on_continuar_presionado() -> void:
	if not validado or bloqueado:
		return
	print("[VincularConceptos] continuar_pressed actividad_completada=true")
	_finalizar_vinculacion()


func _set_click_areas_habilitadas(habilitadas: bool) -> void:
	if click_areas == null:
		return
	for child in click_areas.get_children():
		var area: Button = child as Button
		if area != null:
			area.disabled = not habilitadas


func _bloquear_tarjetas() -> void:
	for tarjeta in _todos_los_items():
		_bloquear_tarjeta(tarjeta)


func _bloquear_tarjeta(tarjeta: ConceptoItem) -> void:
	if not is_instance_valid(tarjeta):
		return
	tarjeta.bloquear_interaccion()
	if click_areas == null:
		return
	for child in click_areas.get_children():
		var area: Button = child as Button
		if area != null and area.get_meta("card", null) == tarjeta:
			area.disabled = true


func _todos_los_items() -> Array[ConceptoItem]:
	var todos: Array[ConceptoItem] = []
	todos.append_array(items_izquierda)
	todos.append_array(items_derecha)
	return todos


func _finalizar_vinculacion() -> void:
	bloqueado = true
	_ocultar_continuar()
	_actualizar_estado_confirmar()
	_bloquear_tarjetas()
	var racha_anterior: Dictionary = Global.obtener_estado_racha()
	_guardar_progreso_de_vinculacion()
	var racha_actualizada: Dictionary = Global.obtener_estado_racha()
	_preparar_flujo_post_juego(racha_anterior, racha_actualizada)
	print("[VincularConceptos] relaciones_completadas=true")
	_al_solicitar_continuar()


func _guardar_progreso_de_vinculacion() -> void:
	if _tiene_sesion_de_mapa:
		Global.marcar_nodo_jugable_completado(clave_pista, _nodo_actual)
		Global.registrar_actividad_racha(
			"map_node_completed",
			{
				"track_key": clave_pista,
				"level_number": nivel_id,
				"node_key": _nodo_actual,
				"mode": NodeContentLoaderScript.MODE_VINCULACION_CONCEPTOS,
			}
		)
		SaveManager.guardar_progreso_en_disco()
		return

	Global.marcar_nivel_completado(clave_pista, nivel_id)
	Global.registrar_actividad_racha(
		"level_completed",
		{"track_key": clave_pista, "level_number": nivel_id}
	)
	SaveManager.registrar_nivel_completado(clave_pista, nivel_id)


func _preparar_flujo_post_juego(racha_anterior: Dictionary, racha_actualizada: Dictionary) -> void:
	_retroalimentacion_racha_post_juego = GameStreakTrackerScript.construir_feedback(
		racha_anterior,
		racha_actualizada,
		true
	)
	var contexto_de_finalizacion: Dictionary = ContextoFinalizacionDeJuegoScript.construir(
		"vinculacion",
		clave_pista,
		nivel_id,
		Global.obtener_pista_nivel_cantidad(clave_pista),
		clave_pista == CLAVE_PISTA_PREDETERMINADA,
		_tiene_sesion_de_mapa,
		_nodo_actual,
		_ruta_escena_de_retorno,
		"vincular_conceptos._preparar_flujo_post_juego"
	)
	_estado_flujo_post_juego = PostGameFlowControllerScript.construir_estado_flujo_post_juego(
		racha_anterior,
		racha_actualizada,
		contexto_de_finalizacion,
		_retroalimentacion_racha_post_juego
	)


func _mostrar_cierre_de_vinculacion() -> void:
	label_pregunta.text = ""
	if _intentar_mostrar_ensenanza_esc():
		return
	_mostrar_asset_de_ensenanza()
	_mostrar_continuar()


func _intentar_mostrar_ensenanza_esc() -> bool:
	var clave_ensenanza: String = str(_datos_de_ejecucion.get("teaching_key", "")).strip_edges()
	if clave_ensenanza.is_empty():
		return false
	# Continuar en EnsenanzaEsc cierra la ensenanza y finaliza la vinculacion
	# (guardado + siguiente juego o cierre de nodo), sin volver a la flecha intermedia.
	var mostrado: bool = PresentadorEnsenanzasScript.mostrar_en_host(
		self,
		clave_ensenanza,
		Callable(self, "_continuar_desde_ensenanza_esc"),
		clave_pista,
		_nodo_actual,
		nivel_id
	)
	if mostrado:
		print("[Teaching] modo=EnsenanzaEsc key=%s" % clave_ensenanza)
	return mostrado


func _continuar_desde_ensenanza_esc() -> void:
	if not validado or bloqueado:
		return
	_on_continuar_presionado()


func _hay_siguiente_juego_de_partida() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return NodoRuntimeScript.hay_siguiente_mini_juego(get_tree())


func _preparar_sprite_ensenanza() -> void:
	teaching_sprite = get_node_or_null("Ensenanza") as Sprite2D
	if teaching_sprite == null:
		teaching_sprite = Sprite2D.new()
		teaching_sprite.name = "Ensenanza"
		add_child(teaching_sprite)
	teaching_sprite.visible = false
	teaching_sprite.top_level = true
	teaching_sprite.z_index = 20
	teaching_sprite.position = Vector2(577, 407)
	teaching_sprite.scale = Vector2(1.33952, 1.33952)


func _mostrar_asset_de_ensenanza() -> void:
	if teaching_sprite == null:
		return
	var textura: Texture2D = _resolver_textura_de_ensenanza()
	if textura == null:
		teaching_sprite.hide()
		push_warning("VincularConceptos: no se encontro asset de ensenanza.")
		return
	teaching_sprite.texture = textura
	teaching_sprite.show()


func _resolver_textura_de_ensenanza() -> Texture2D:
	var clave_ensenanza: String = str(_datos_de_ejecucion.get("teaching_key", "")).strip_edges()
	var fallback_path := ""
	if clave_ensenanza.is_empty():
		var definicion_capitulo: Dictionary = Global.obtener_capitulo_partida_definicion(
			clave_pista,
			nivel_id,
			1
		)
		clave_ensenanza = str(definicion_capitulo.get("teaching_key", "")).strip_edges()
		fallback_path = str(definicion_capitulo.get("teaching_texture_path", "")).strip_edges()
	return GameChapterAssetCatalogScript.resolver_textura_ensenanza_para_contexto(
		clave_pista,
		clave_ensenanza,
		_nodo_actual,
		fallback_path,
		nivel_id
	)


func continuar_al_siguiente_juego() -> void:
	if validado and not bloqueado:
		_on_continuar_presionado()
		return
	_al_solicitar_continuar()


func _al_solicitar_continuar_juego() -> void:
	if _continuar_juego_es_validacion_pendiente:
		_on_continuar_presionado()
		return
	if _continuar_juego_es_continuacion_pendiente:
		GameSceneRouter.go_to_continue_target(get_tree(), _ruta_escena_de_retorno)
		return
	_al_solicitar_continuar()


func _al_solicitar_continuar() -> void:
	if ya_continuo:
		return
	ya_continuo = true
	_limpiar_elementos_temporales()
	_continuar_despues_de_ensenanza(true)


## Cumple el contrato de ModalidadBase. Devuelve el resultado de este mini juego de vinculacion.
func obtener_resultado() -> ResultadoDeMiniJuego:
	var total := maxi(1, _pares_vinculados_total)
	return ResultadoDeMiniJuegoScript.crear_detallado(
		"vinculacion",
		_pares_vinculados_correctos,
		total - _pares_vinculados_correctos,
		total
	)


func _continuar_partida_de_nodo_si_corresponde() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return NodoRuntimeScript.finalizar_mini_juego(
		get_tree(),
		Callable(self, "_limpiar_elementos_temporales"),
		Callable(self, "_limpiar_estado_de_partida_local")
	)


func _continuar_despues_de_ensenanza(temporizador_finalizado: bool) -> void:
	if _continuar_partida_de_nodo_si_corresponde():
		return

	if _estado_flujo_post_juego.is_empty():
		_volver_a_escena_de_mapa()
		return

	PostGameFlowControllerScript.navegar_despues_ensenanza(
		get_tree(),
		_tomar_estado_flujo_post_juego(),
		_tomar_retroalimentacion_racha_post_juego(),
		temporizador_finalizado
	)


func _limpiar_elementos_temporales() -> void:
	_continuar_juego_es_validacion_pendiente = false
	PresentadorContinuarJuegoScript.ocultar(_continuar_juego)


func _limpiar_estado_de_partida_local() -> void:
	_limpiar_elementos_temporales()
	_pertenece_a_partida_de_nodo = false


func _tomar_estado_flujo_post_juego() -> Dictionary:
	var estado_flujo: Dictionary = _estado_flujo_post_juego.duplicate(true)
	_estado_flujo_post_juego = {}
	return estado_flujo


func _tomar_retroalimentacion_racha_post_juego() -> Dictionary:
	var retroalimentacion: Dictionary = _retroalimentacion_racha_post_juego.duplicate(true)
	_retroalimentacion_racha_post_juego = {}
	return retroalimentacion


func _mostrar_error_bloqueante(mensaje: String) -> void:
	bloqueado = true
	_limpiar_elementos_temporales()
	label_pregunta.text = mensaje
	_limpiar_vinculos_y_errores()
	_actualizar_visual()
	_bloquear_tarjetas()


func _on_atras_presionado() -> void:
	_finalizar_actividad(false)

func _volver_a_escena_de_mapa() -> void:
	_finalizar_actividad(true)

func _calcular_elapsed_seconds() -> float:
	if _activity_started_msec <= 0:
		push_warning("[TimeTracker] activity_started_msec no inicializado.")
		return -1.0
	var elapsed := float(Time.get_ticks_msec() - _activity_started_msec) / 1000.0
	print("[TimeTracker] elapsed_seconds=", elapsed)
	return elapsed

func _finalizar_actividad(success: bool) -> void:
	if finalizacion_enviada:
		print("[VincularConceptos] evitar_doble_finalizacion")
		return
	finalizacion_enviada = true
	_limpiar_elementos_temporales()
	var activity_id: String = str(_datos_de_ejecucion.get("id", _datos_de_ejecucion.get("activity_id", "")))
	print("[VincularConceptos] finalizar_actividad activity_id=", activity_id)
	var _precision_real: int = NodoRuntimeScript.calcular_precision(get_tree())
	var resultado := {
		"activity_id": activity_id,
		"node_key": _nodo_actual,
		"map_id": SyncApi.resolver_restriccion_para_partida(get_tree(), {}, clave_pista),
		"success": success,
		"accuracy": clampf(float(_precision_real) / 100.0, 0.0, 1.0),
		"exp": 10,
		"elapsed_seconds": _calcular_elapsed_seconds()
	}
	PostGameFlowControllerScript.finalizar_actividad(get_tree(), resultado)
