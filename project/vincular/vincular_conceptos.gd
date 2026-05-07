extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
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
	"res://mapas/core/ContinuidadDePartidaDeNodo.gd"
)
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const PresentadorContinuarJuegoScript := preload(
	"res://interface/components/ContinuarJuego/PresentadorContinuarJuego.gd"
)
const CLAVE_PISTA_PREDETERMINADA := "celiaquia"
const ESCENA_RETORNO_PREDETERMINADA := GameSceneRouter.MAP_SCENE_PATH
const BADGE_TEXTURE := preload("res://assets-sistema/interfaz/pregunta-1.png")
const BADGE_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")
const COLOR_TARJETA_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TARJETA_SELECCIONADA := Color(0.93, 1.0, 0.95, 1.0)
const COLOR_TARJETA_VINCULADA := Color(0.97, 1.0, 0.98, 1.0)
const COLOR_TARJETA_ERROR := Color(1.0, 0.94, 0.94, 1.0)
const COLOR_LINEA_OK := Color(0.2, 0.62, 0.38, 1.0)
const COLOR_LINEA_ERROR := Color(0.92, 0.22, 0.2, 1.0)
const COLOR_LINEA_SOMBRA := Color(0.05, 0.04, 0.03, 0.28)
const MARGEN_ANCLAJE_LINEA := 12.0
const DURACION_ANIMACION_LINEA := 0.16

@onready var label_pregunta: Label = $Control/LabelPregunta
@onready var titulo_nivel: Label = $TituloNivel/Label
@onready var contenedor_izquierda: VBoxContainer = $Control/VBoxIzquierda
@onready var contenedor_derecha: VBoxContainer = $Control/VBoxDerecha
@onready var control_principal: Control = $Control
@onready var line_drawer: Line2D = $Control/LineDrawer
@onready var boton_atras: Button = $"Atrás"
@onready var indicador_de_progreso_de_juego = $IndicadorProgresoDeJuego
@onready var _continuar_juego = $ContinuarJuego

var selected_left_id := ""
var links: Dictionary = {}
var correct_links: Dictionary = {}
var left_cards: Dictionary = {}
var right_cards: Dictionary = {}

var total_pares := 0
var clave_pista := CLAVE_PISTA_PREDETERMINADA
var nivel_id := 1
var bloqueado := false
var ya_continuo := false
var validacion_correcta := false
var boton_confirmar: Button = null
var boton_continuar_validacion: Button = null
var feedback_label: Label = null
var click_areas: Control = null

var _nodo_actual: String = ""
var _tiene_sesion_de_mapa := false
var _pertenece_a_partida_de_nodo := false
var _ruta_escena_de_retorno := ESCENA_RETORNO_PREDETERMINADA
var _mensaje_error_bloqueante := ""
var _retroalimentacion_racha_post_juego: Dictionary = {}
var _estado_flujo_post_juego: Dictionary = {}
var _datos_de_ejecucion: Dictionary = {}
var _items_izquierda: Array[ConceptoItem] = []
var _items_derecha: Array[ConceptoItem] = []
var _lineas_incorrectas: Dictionary = {}
var _lineas_para_animar: Dictionary = {}


func _ready() -> void:
	_recolectar_items()
	_preparar_controles_de_confirmacion()
	_preparar_click_areas()
	_acomodar_pantalla()
	if line_drawer != null:
		line_drawer.z_as_relative = false
		line_drawer.z_index = 80
		line_drawer.show()
	_conectar_continuar_juego()
	if boton_atras != null:
		boton_atras.pressed.connect(_on_atras_presionado)
	configurar_desde_sesion()
	_configurar_indicador_de_progreso_de_juego()
	if not _mensaje_error_bloqueante.is_empty():
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	_aplicar_runtime_en_escena()


func _recolectar_items() -> void:
	_items_izquierda = _extraer_conceptos(contenedor_izquierda)
	_items_derecha = _extraer_conceptos(contenedor_derecha)


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
	if _continuar_juego.has_signal("continuar_solicitado"):
		_continuar_juego.connect("continuar_solicitado", Callable(self, "_al_solicitar_continuar"))


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
	clave_pista = str(contexto_sesion.get("track_key", clave_pista)).strip_edges()
	nivel_id = int(contexto_sesion.get("level_number", contexto_sesion.get("nivel_id", nivel_id)))
	_nodo_actual = str(contexto_sesion.get("node_key", "")).strip_edges()
	_pertenece_a_partida_de_nodo = bool(
		contexto_sesion.get("pertenece_a_partida_de_nodo", false)
	)
	_ruta_escena_de_retorno = str(
		contexto_sesion.get("return_to", ESCENA_RETORNO_PREDETERMINADA)
	).strip_edges()
	if _ruta_escena_de_retorno.is_empty():
		_ruta_escena_de_retorno = ESCENA_RETORNO_PREDETERMINADA
	_tiene_sesion_de_mapa = bool(
		contexto_sesion.get("came_from_map", not _nodo_actual.is_empty())
	)


func _cargar_datos_de_vinculacion(contexto_sesion: Dictionary) -> void:
	var ruta_json: String = str(contexto_sesion.get("json_path", "")).strip_edges()
	if ruta_json.is_empty():
		_mensaje_error_bloqueante = "Falta json_path para la vinculación."
		return

	var resultado_nodo: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(ruta_json)
	if not bool(resultado_nodo.get("ok", false)):
		_mensaje_error_bloqueante = str(
			resultado_nodo.get("error", "No se pudo cargar el contenido de vinculación.")
		)
		return

	var resultado_runtime: Dictionary = NodeContentLoaderScript.convertir_vinculacion_a_runtime(
		resultado_nodo.get("data", {})
	)
	if not bool(resultado_runtime.get("ok", false)):
		_mensaje_error_bloqueante = str(
			resultado_runtime.get("error", "No se pudo preparar la vinculación.")
		)
		return

	_datos_de_ejecucion = resultado_runtime.get("data", {}).duplicate(true)


func _reiniciar_estado_local() -> void:
	selected_left_id = ""
	links = {}
	correct_links = {}
	left_cards = {}
	right_cards = {}
	_lineas_incorrectas = {}
	_lineas_para_animar = {}
	total_pares = 0
	bloqueado = false
	ya_continuo = false
	validacion_correcta = false
	_nodo_actual = ""
	_tiene_sesion_de_mapa = false
	_pertenece_a_partida_de_nodo = false
	_ruta_escena_de_retorno = ESCENA_RETORNO_PREDETERMINADA
	_mensaje_error_bloqueante = ""
	_retroalimentacion_racha_post_juego = {}
	_estado_flujo_post_juego = {}
	_datos_de_ejecucion = {}


func _preparar_controles_de_confirmacion() -> void:
	boton_confirmar = control_principal.get_node_or_null("ConfirmButton") as Button
	if boton_confirmar == null:
		boton_confirmar = Button.new()
		boton_confirmar.name = "ConfirmButton"
		boton_confirmar.custom_minimum_size = Vector2(220, 56)
		control_principal.add_child(boton_confirmar)
	boton_confirmar.position = Vector2(520, 724)
	boton_confirmar.text = "Confirmar"
	boton_confirmar.visible = true
	boton_confirmar.disabled = true
	boton_confirmar.z_index = 110
	_aplicar_estilo_boton_badge(boton_confirmar, 24)
	if not boton_confirmar.pressed.is_connected(_on_confirmar_pressed):
		boton_confirmar.pressed.connect(_on_confirmar_pressed)

	_preparar_boton_continuar_validacion()

	feedback_label = control_principal.get_node_or_null("FeedbackLabel") as Label
	if feedback_label == null:
		feedback_label = Label.new()
		feedback_label.name = "FeedbackLabel"
		feedback_label.custom_minimum_size = Vector2(520, 40)
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		control_principal.add_child(feedback_label)
	feedback_label.position = Vector2(370, 688)
	feedback_label.visible = true
	feedback_label.z_index = 110
	feedback_label.text = ""


func _preparar_boton_continuar_validacion() -> void:
	boton_continuar_validacion = (
		control_principal.get_node_or_null("ContinueButton") as Button
	)
	if boton_continuar_validacion == null:
		boton_continuar_validacion = Button.new()
		boton_continuar_validacion.name = "ContinueButton"
		boton_continuar_validacion.custom_minimum_size = Vector2(236, 56)
		control_principal.add_child(boton_continuar_validacion)
	boton_continuar_validacion.position = Vector2(512, 724)
	boton_continuar_validacion.text = "Continuar"
	boton_continuar_validacion.visible = false
	boton_continuar_validacion.disabled = true
	boton_continuar_validacion.z_index = 111
	_aplicar_estilo_boton_badge(boton_continuar_validacion, 28)
	if not boton_continuar_validacion.pressed.is_connected(_on_continuar_pressed):
		boton_continuar_validacion.pressed.connect(_on_continuar_pressed)


func _aplicar_estilo_boton_badge(boton: Button, font_size: int) -> void:
	var estilo := _crear_estilo_badge()
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_font_override("font", BADGE_FONT)
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
	label_pregunta.position = Vector2(245, 198)
	label_pregunta.size = Vector2(730, 86)
	label_pregunta.scale = Vector2.ONE
	label_pregunta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_pregunta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_pregunta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_pregunta.add_theme_font_size_override("font_size", 34)

	contenedor_izquierda.position = Vector2(360, 334)
	contenedor_derecha.position = Vector2(805, 334)
	contenedor_izquierda.add_theme_constant_override("separation", 124)
	contenedor_derecha.add_theme_constant_override("separation", 124)


func _preparar_click_areas() -> void:
	click_areas = control_principal.get_node_or_null("ClickAreas") as Control
	if click_areas == null:
		click_areas = Control.new()
		click_areas.name = "ClickAreas"
		click_areas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		click_areas.z_index = 100
		control_principal.add_child(click_areas)
	click_areas.visible = true
	click_areas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_areas.z_index = 100


func _limpiar_click_areas() -> void:
	if click_areas == null:
		return
	for child in click_areas.get_children():
		click_areas.remove_child(child)
		child.queue_free()


func _configurar_indicador_de_progreso_de_juego() -> void:
	if indicador_de_progreso_de_juego == null:
		return
	var contexto: Dictionary = ContextoSesionDeJuegoScript.obtener_modelo_indicador_actual()
	indicador_de_progreso_de_juego.show()
	indicador_de_progreso_de_juego.actualizar(
		str(contexto.get("titulo", "")).strip_edges(),
		int(contexto.get("actual", 1)),
		int(contexto.get("total", 1))
	)


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
	if total_pares > _items_izquierda.size() or total_pares > _items_derecha.size():
		_mostrar_error_bloqueante("La escena de vinculación no tiene suficientes tarjetas visuales.")
		return
	validacion_correcta = false
	_ocultar_continuar()
	_limpiar_click_areas()
	_armar_respuestas_correctas(conceptos_izquierda, conceptos_derecha)
	var conceptos_derecha_ordenados: Array = _ordenar_derecha_para_evitar_cruces(
		conceptos_izquierda,
		conceptos_derecha
	)
	_configurar_lado(_items_izquierda, conceptos_izquierda, "izquierda")
	_configurar_lado(_items_derecha, conceptos_derecha_ordenados, "derecha")
	_actualizar_visual()
	print("TOTAL PARES: ", total_pares)
	print("CORRECT LINKS: ", correct_links)
	call_deferred("_sincronizar_layout_interactivo")


func _sincronizar_layout_interactivo() -> void:
	await get_tree().process_frame
	_actualizar_visual()


func _armar_respuestas_correctas(conceptos_izquierda: Array, conceptos_derecha: Array) -> void:
	correct_links = {}
	var derecha_por_par: Dictionary = {}
	for concepto_derecha in conceptos_derecha:
		var datos_derecha: Dictionary = concepto_derecha as Dictionary
		var id_par_derecha: String = str(datos_derecha.get("id_par", "")).strip_edges()
		var id_derecha: String = str(datos_derecha.get("id", "")).strip_edges()
		if not id_par_derecha.is_empty() and not id_derecha.is_empty():
			derecha_por_par[id_par_derecha] = id_derecha

	for concepto_izquierda in conceptos_izquierda:
		var datos_izquierda: Dictionary = concepto_izquierda as Dictionary
		var id_izquierda: String = str(datos_izquierda.get("id", "")).strip_edges()
		var id_par_izquierda: String = str(datos_izquierda.get("id_par", "")).strip_edges()
		if id_izquierda.is_empty():
			continue
		correct_links[id_izquierda] = str(derecha_por_par.get(id_par_izquierda, ""))


func _ordenar_derecha_para_evitar_cruces(conceptos_izquierda: Array, conceptos_derecha: Array) -> Array:
	var derecha_por_par: Dictionary = {}
	var usados: Dictionary = {}
	for concepto_derecha in conceptos_derecha:
		var datos_derecha: Dictionary = concepto_derecha as Dictionary
		var id_par: String = str(datos_derecha.get("id_par", "")).strip_edges()
		if not derecha_por_par.has(id_par):
			derecha_por_par[id_par] = []
		derecha_por_par[id_par].append(datos_derecha)

	var ordenados: Array = []
	for concepto_izquierda in conceptos_izquierda:
		var datos_izquierda: Dictionary = concepto_izquierda as Dictionary
		var id_par_izquierda: String = str(datos_izquierda.get("id_par", "")).strip_edges()
		var candidatos: Array = derecha_por_par.get(id_par_izquierda, [])
		if candidatos.is_empty():
			continue
		var elegido: Dictionary = candidatos.pop_front()
		ordenados.append(elegido)
		usados[str(elegido.get("id", ""))] = true

	for concepto_derecha in conceptos_derecha:
		var datos_derecha: Dictionary = concepto_derecha as Dictionary
		var id_derecha: String = str(datos_derecha.get("id", "")).strip_edges()
		if not usados.has(id_derecha):
			ordenados.append(datos_derecha)

	return ordenados


func _configurar_lado(
	items_escena: Array[ConceptoItem],
	conceptos: Array,
	lado: String
) -> void:
	for indice in range(items_escena.size()):
		var item: ConceptoItem = items_escena[indice]
		if indice >= conceptos.size():
			item.hide()
			item.disabled = true
			item.bloqueado = true
			continue

		var concepto: Dictionary = conceptos[indice] as Dictionary
		item.show()
		item.disabled = false
		item.bloqueado = false
		_aplicar_estado_tarjeta(item, "normal")
		item.lado = lado
		item.par_id = _firmar_id_par(str(concepto.get("id_par", "")).strip_edges())
		var concept_id: String = str(concepto.get("id", "")).strip_edges()
		item.set_meta("concept_id", concept_id)
		item.ajustar_titulo(str(concepto.get("texto", "")).strip_edges())
		_hacer_tarjeta_clickeable(item, concept_id, lado == "izquierda")
		if lado == "izquierda":
			left_cards[concept_id] = item
		else:
			right_cards[concept_id] = item


func _hacer_tarjeta_clickeable(card: ConceptoItem, id: String, es_izquierda: bool) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.disabled = false
	card.bloqueado = false
	card.set_meta("concept_id", id)
	card.set_meta("es_izquierda", es_izquierda)
	_ignorar_mouse_en_hijos(card)
	var hotspot_viejo := card.get_node_or_null("ClickHotspot")
	if hotspot_viejo != null:
		card.remove_child(hotspot_viejo)
		hotspot_viejo.queue_free()
	_crear_area_click_sobre_tarjeta(card, id, es_izquierda)


func _ignorar_mouse_en_hijos(node: Node) -> void:
	for child in node.get_children():
		if child.name == "ClickHotspot":
			continue
		var control_child: Control = child as Control
		if control_child != null:
			control_child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignorar_mouse_en_hijos(child)


func _crear_area_click_sobre_tarjeta(card: Control, id: String, es_izquierda: bool) -> Button:
	var area := Button.new()
	area.name = "ClickArea_%s" % id
	area.text = ""
	area.flat = true
	area.focus_mode = Control.FOCUS_NONE
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.self_modulate = Color(1, 1, 1, 0)
	area.set_meta("concept_id", id)
	area.set_meta("es_izquierda", es_izquierda)
	area.set_meta("card", card)
	area.pressed.connect(Callable(self, "_on_area_click_pressed").bind(area))
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
	area.disabled = bloqueado or validacion_correcta


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


func _on_area_click_pressed(area: Button) -> void:
	var id: String = str(area.get_meta("concept_id", "")).strip_edges()
	var es_izquierda: bool = bool(area.get_meta("es_izquierda", false))
	if id.is_empty():
		return
	if es_izquierda:
		_on_left_pressed(id)
	else:
		_on_right_pressed(id)


func _firmar_id_par(id_par: String) -> int:
	var firma := 0
	for indice in range(id_par.length()):
		firma = int((firma * 31 + id_par.unicode_at(indice) + indice + 1) % 2147483647)
	return firma


func _on_item_seleccionado(item: ConceptoItem) -> void:
	if bloqueado or item == null or item.bloqueado:
		return

	var concept_id := _obtener_id_item(item)
	if concept_id.is_empty():
		return

	if item.lado == "izquierda":
		_on_left_pressed(concept_id)
	elif item.lado == "derecha":
		_on_right_pressed(concept_id)


func _on_left_pressed(left_id: String) -> void:
	if bloqueado or validacion_correcta:
		return
	print("LEFT CLICK: ", left_id)
	selected_left_id = left_id
	print("SELECTED LEFT: ", selected_left_id)
	_mostrar_feedback("Elegí una tarjeta de la derecha.")
	_actualizar_tarjetas()


func _on_right_pressed(right_id: String) -> void:
	if bloqueado or validacion_correcta:
		return
	print("RIGHT CLICK: ", right_id)
	if selected_left_id.is_empty():
		_mostrar_feedback("Primero elegí una tarjeta de la izquierda.")
		return

	_crear_o_actualizar_link(selected_left_id, right_id)
	selected_left_id = ""
	_mostrar_feedback("Vínculo creado.")


func _crear_o_actualizar_link(left_id: String, right_id: String) -> void:
	var left_reemplazado := ""
	for other_left_id in links.keys():
		if str(other_left_id) != left_id and str(links[other_left_id]) == right_id:
			left_reemplazado = str(other_left_id)
			links.erase(other_left_id)
			break

	links[left_id] = right_id
	print("LINKS: ", links)
	_lineas_incorrectas.erase(left_id)
	if not left_reemplazado.is_empty():
		_lineas_incorrectas.erase(left_reemplazado)
	_lineas_para_animar[left_id] = true
	validacion_correcta = false
	_ocultar_continuar()
	_actualizar_visual()


func _actualizar_estado_confirmar() -> void:
	if boton_confirmar == null:
		return
	boton_confirmar.visible = not validacion_correcta
	boton_confirmar.disabled = links.size() < total_pares or bloqueado or validacion_correcta
	print("CONFIRM DISABLED: ", boton_confirmar.disabled)


func _actualizar_visual() -> void:
	_actualizar_tarjetas()
	_actualizar_lineas()
	_actualizar_estado_confirmar()
	_actualizar_areas_click()


func _actualizar_tarjetas() -> void:
	for left_id in left_cards.keys():
		var item: Control = left_cards[left_id] as Control
		if not is_instance_valid(item):
			continue
		if _lineas_incorrectas.has(left_id):
			_aplicar_estado_tarjeta(item, "error")
		elif str(left_id) == selected_left_id:
			_aplicar_estado_tarjeta(item, "seleccionada")
		elif links.has(left_id):
			_aplicar_estado_tarjeta(item, "vinculada")
		else:
			_aplicar_estado_tarjeta(item, "normal")

	for right_id in right_cards.keys():
		var item: Control = right_cards[right_id] as Control
		if not is_instance_valid(item):
			continue
		if _derecha_tiene_error(str(right_id)):
			_aplicar_estado_tarjeta(item, "error")
		elif _derecha_esta_usada(str(right_id)):
			_aplicar_estado_tarjeta(item, "vinculada")
		else:
			_aplicar_estado_tarjeta(item, "normal")


func _aplicar_estado_tarjeta(item: Control, tipo: String) -> void:
	match tipo:
		"seleccionada":
			item.modulate = COLOR_TARJETA_SELECCIONADA
		"vinculada":
			item.modulate = COLOR_TARJETA_VINCULADA
		"error":
			item.modulate = COLOR_TARJETA_ERROR
		_:
			item.modulate = COLOR_TARJETA_NORMAL


func _derecha_esta_usada(right_id: String) -> bool:
	for linked_right_id in links.values():
		if str(linked_right_id) == right_id:
			return true
	return false


func _derecha_tiene_error(right_id: String) -> bool:
	for left_id in _lineas_incorrectas.keys():
		if str(links.get(left_id, "")) == right_id:
			return true
	return false


func _obtener_id_item(item: ConceptoItem) -> String:
	return str(item.get_meta("concept_id", "")).strip_edges()


func _mostrar_feedback(texto: String) -> void:
	if feedback_label == null:
		return
	feedback_label.text = texto


func _actualizar_lineas() -> void:
	if line_drawer == null:
		return
	for child in line_drawer.get_children():
		line_drawer.remove_child(child)
		child.queue_free()

	for left_id in links.keys():
		_dibujar_linea_de_vinculo(str(left_id))


func _dibujar_linea_de_vinculo(left_id: String) -> void:
	var right_id: String = str(links.get(left_id, ""))
	var left_card: Control = left_cards.get(left_id, null) as Control
	var right_card: Control = right_cards.get(right_id, null) as Control
	if not is_instance_valid(left_card) or not is_instance_valid(right_card):
		return

	var color := COLOR_LINEA_OK
	if _lineas_incorrectas.has(left_id):
		color = COLOR_LINEA_ERROR

	var origen: Vector2 = _get_right_anchor(left_card)
	var destino: Vector2 = _get_left_anchor(right_card)
	var debe_animar := bool(_lineas_para_animar.get(left_id, false))
	_crear_linea(origen, destino, COLOR_LINEA_SOMBRA, 7.0, debe_animar)
	_crear_linea(origen, destino, color, 4.0, debe_animar)
	_lineas_para_animar.erase(left_id)


func _get_right_anchor(card: Control) -> Vector2:
	var rect := _obtener_rect_visual_tarjeta(card)
	var punto_global := Vector2(
		rect.position.x + rect.size.x - MARGEN_ANCLAJE_LINEA,
		rect.position.y + rect.size.y * 0.5
	)
	return line_drawer.to_local(punto_global)


func _get_left_anchor(card: Control) -> Vector2:
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
	linea.add_point(origen)
	if animar:
		linea.add_point(origen)
	else:
		linea.add_point(destino)
	line_drawer.add_child(linea)
	if animar:
		_animar_linea(linea, origen, destino)


func _animar_linea(linea: Line2D, origen: Vector2, destino: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		Callable(self, "_mover_fin_linea").bind(linea),
		origen,
		destino,
		DURACION_ANIMACION_LINEA
	)


func _mover_fin_linea(punto: Vector2, linea: Line2D) -> void:
	if is_instance_valid(linea):
		linea.set_point_position(1, punto)


func _on_confirmar_pressed() -> void:
	if bloqueado:
		return
	if links.size() < total_pares:
		_mostrar_feedback("Faltan relaciones por completar.")
		return
	if _validar_links():
		validacion_correcta = true
		_mostrar_feedback("¡Muy bien!")
		_mostrar_continuar()
		_actualizar_visual()
		return
	validacion_correcta = false
	_ocultar_continuar()
	_mostrar_error_de_validacion()


func _validar_links() -> bool:
	_lineas_incorrectas = {}
	for left_id in correct_links.keys():
		if str(links.get(left_id, "")) != str(correct_links[left_id]):
			_lineas_incorrectas[left_id] = true
	return _lineas_incorrectas.is_empty()


func _mostrar_error_de_validacion() -> void:
	_mostrar_feedback("Revisá las relaciones marcadas.")
	_actualizar_tarjetas()
	_actualizar_lineas()


func _mostrar_continuar() -> void:
	if boton_continuar_validacion == null:
		return
	boton_continuar_validacion.disabled = false
	boton_continuar_validacion.visible = true
	boton_continuar_validacion.modulate = Color(1, 1, 1, 1)
	_set_click_areas_habilitadas(false)


func _ocultar_continuar() -> void:
	if boton_continuar_validacion == null:
		return
	boton_continuar_validacion.visible = false
	boton_continuar_validacion.disabled = true
	if not bloqueado:
		_set_click_areas_habilitadas(true)


func _on_continuar_pressed() -> void:
	if not validacion_correcta or bloqueado:
		return
	_finalizar_vinculacion()


func _set_click_areas_habilitadas(habilitadas: bool) -> void:
	if click_areas == null:
		return
	for child in click_areas.get_children():
		var area: Button = child as Button
		if area != null:
			area.disabled = not habilitadas


func _bloquear_tarjetas() -> void:
	for tarjeta in _items_izquierda:
		_bloquear_tarjeta(tarjeta)
	for tarjeta in _items_derecha:
		_bloquear_tarjeta(tarjeta)


func _bloquear_tarjeta(tarjeta: ConceptoItem) -> void:
	if not is_instance_valid(tarjeta):
		return
	tarjeta.bloqueado = true
	if click_areas == null:
		return
	for child in click_areas.get_children():
		var area: Button = child as Button
		if area != null and area.get_meta("card", null) == tarjeta:
			area.disabled = true


func _finalizar_vinculacion() -> void:
	bloqueado = true
	_ocultar_continuar()
	_actualizar_estado_confirmar()
	_bloquear_tarjetas()
	var racha_anterior: Dictionary = Global.obtener_estado_racha()
	_guardar_progreso_de_vinculacion()
	var racha_actualizada: Dictionary = Global.obtener_estado_racha()
	_preparar_flujo_post_juego(racha_anterior, racha_actualizada)
	_mostrar_cierre_de_vinculacion()


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


func _preparar_flujo_post_juego(
	racha_anterior: Dictionary,
	racha_actualizada: Dictionary
) -> void:
	_retroalimentacion_racha_post_juego = GameStreakTrackerScript.build_feedback(
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
	_estado_flujo_post_juego = PostGameFlowControllerScript.build_post_game_flow_state(
		racha_anterior,
		racha_actualizada,
		contexto_de_finalizacion,
		_retroalimentacion_racha_post_juego
	)


func _mostrar_cierre_de_vinculacion() -> void:
	label_pregunta.text = _resolver_texto_de_cierre()
	_mostrar_continuacion()


func _mostrar_continuacion() -> void:
	ya_continuo = false
	PresentadorContinuarJuegoScript.mostrar(_continuar_juego, _hay_siguiente_juego_de_partida(), 5)


func _hay_siguiente_juego_de_partida() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(get_tree())


func _resolver_texto_de_cierre() -> String:
	var texto_retroalimentacion: String = str(
		_datos_de_ejecucion.get("retroalimentacion_ok", "")
	).strip_edges()
	var texto_ensenanza: String = str(_datos_de_ejecucion.get("ensenanza", "")).strip_edges()
	var partes: Array[String] = []
	if not texto_retroalimentacion.is_empty():
		partes.append(texto_retroalimentacion)
	if not texto_ensenanza.is_empty():
		partes.append(texto_ensenanza)
	if partes.is_empty():
		partes.append("¡Muy bien! Ya podés seguir con el próximo juego.")
	return "\n".join(partes)


func continuar_al_siguiente_juego() -> void:
	_al_solicitar_continuar()


func _al_solicitar_continuar() -> void:
	if ya_continuo:
		return
	ya_continuo = true
	_limpiar_elementos_temporales()
	_continuar_despues_de_ensenanza(true)


func _continuar_partida_de_nodo_si_corresponde() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return ContinuidadDePartidaDeNodoScript.continuar_o_finalizar_partida(
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

	PostGameFlowControllerScript.navigate_after_teaching(
		get_tree(),
		_tomar_estado_flujo_post_juego(),
		_tomar_retroalimentacion_racha_post_juego(),
		temporizador_finalizado
	)


func _limpiar_elementos_temporales() -> void:
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
	_actualizar_estado_confirmar()
	_bloquear_tarjetas()
	links = {}
	_actualizar_lineas()


func _on_atras_presionado() -> void:
	if _pertenece_a_partida_de_nodo:
		Global.finalizar_partida_de_nodo()
		Global.limpiar_sesion_nodo_jugable_activo()
	_volver_a_escena_de_mapa()


func _volver_a_escena_de_mapa() -> void:
	_limpiar_elementos_temporales()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_de_retorno
	)
