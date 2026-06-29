# HELPER_INTERNO
# Nodo visual individual del mapa (estrella/candado/completado).
# Solo renderizariza estado — no decide flujo.
# Visibilidad en runtime: MapBoard.configurar_nodos muestra todos los nodos del mapa.
extends Node2D
# HELPER_INTERNO
const DEBUG_BADGES := false
# Nodo visual individual del mapa (estrella/candado/completado).

signal selected(node_data: MapNodeData)

const COLOR_AVAILABLE := MiPaleta.GRIS_AZULADO
const COLOR_LOCKED := Color(1, 1, 1, 0.28)
const STATE_COMPLETED := "completed"
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"
const INDICADOR_LECCION_SCENE := preload("res://mapas/components/IndicadorLeccionSiguiente.tscn")
const ICONO_NODO_MAPA_UNIFICADO := preload("res://assets-sistema/mapa/desafio-mapa-8.png")
const ESCALA_ICONO_NODO_UNIFICADO := Vector2(0.28, 0.28)
const ESCALA_NODO_UNIFICADA := Vector2.ONE

@export_group("Runtime")
@export var nivel_id: int = 0
@export var unlocked: bool = false:
	set(value):
		unlocked = value
		actualizar_vista()
@export var completed: bool = false:
	set(value):
		completed = value
		actualizar_vista()
@export var can_play: bool = false:
	set(value):
		can_play = value
		actualizar_vista()
@export_enum("completed", "available", "locked") var visual_state: String = STATE_LOCKED:
	set(value):
		visual_state = _sanitizar_estado_visual(value)
		actualizar_vista()

@export_group("Scene Compatibility")
## Solo visual/decorativo. No afecta la apertura de partida, la modalidad ni ArmadorDePartida.
## MapChapterNode.tscn y MapQuestionNode.tscn usan este mismo script con node_kind distinto.
@export_enum("chapter", "question") var node_kind: String = "chapter"
@export var level_number: int = 0
@export var question_number: int = 0
@export var node_key: String = ""
@export var label_text: String = "Nodo":
	set(value):
		label_text = value.strip_edges()
		actualizar_vista()

@export_group("View")
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		actualizar_vista()
# debug_progress / debug_completed: solo para pruebas en editor. Dejar en -1/false para producción.
@export_range(-1.0, 1.0, 0.05) var debug_progress: float = -1.0
@export var debug_completed: bool = false

@export_group("Appearance")
## Escala del sprite interno ($Icon). Vector2.ZERO = no override (usa valor del .tscn).
@export var icon_scale: Vector2 = Vector2.ZERO
## Posición del sprite interno ($Icon). Vector2.ZERO = no override (usa valor del .tscn).
@export var icon_offset: Vector2 = Vector2.ZERO
## Material del sprite interno ($Icon). null = no override (usa material del .tscn).
@export var icon_material: Material = null
## Posición del badge de progreso ($NodeProgressBadge). Vector2.ZERO = no override (usa valor del .tscn).
@export var badge_offset: Vector2 = Vector2.ZERO

var node_data: MapNodeData = null
var _base_scale: Vector2 = Vector2.ONE
var _is_hovering: bool = false
var _click_in_progress: bool = false
var _disponible_tween: Tween = null
var _best_accuracy: float = 0.0
var _best_percent: float = 0.0
var _es_nodo_recomendado: bool = false
var _indicador_activo_previo: bool = false

@onready var button: TextureButton = $Button
@onready var state_icon: Sprite2D = $Icon
@onready var title_label: Label = get_node_or_null("TitleLabel") as Label
@onready var node_badge: Node2D = get_node_or_null("NodeProgressBadge")
var _indicador_leccion: Node2D = null


func _ready() -> void:
	_base_scale = scale
	_asegurar_indicador_leccion()
	actualizar_vista()


func configurar(
	data: MapNodeData,
	progress_state: Variant = {},
	is_completed: bool = false
) -> void:
	_cancelar_tween_disponible()
	node_data = data
	if progress_state is Dictionary:
		_aplicar_estado_progreso(progress_state as Dictionary)
	else:
		_aplicar_estado_progreso_legado(bool(progress_state), is_completed)
	reiniciar_escala_base()
	aplicar_presentacion_unificada()
	actualizar_vista()


func reiniciar_escala_base() -> void:
	_cancelar_tween_disponible()
	if _is_hovering:
		_is_hovering = false
	scale = ESCALA_NODO_UNIFICADA
	_base_scale = ESCALA_NODO_UNIFICADA


func aplicar_presentacion_unificada() -> void:
	# Sprint 2: un solo look por nodo. Evita halos verdes gigantes de preguntas
	# con texturas/escalas distintas heredadas del editor (MapChapter vs MapQuestion).
	icon_texture = ICONO_NODO_MAPA_UNIFICADO
	icon_scale = ESCALA_ICONO_NODO_UNIFICADO
	icon_material = null
	reiniciar_escala_base()


func es_leccion_actual() -> bool:
	return _es_nodo_recomendado and visual_state == STATE_AVAILABLE and not completed


func actualizar_vista() -> void:
	if not is_node_ready():
		return

	state_icon.texture = icon_texture
	if title_label != null:
		title_label.text = _obtener_titulo()
	if button != null:
		button.tooltip_text = ""
		button.disabled = _boton_esta_deshabilitado()
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW
			if button.disabled
			else Control.CURSOR_POINTING_HAND
		)
	_aplicar_color_estado()
	_aplicar_parametros_visuales()
	_actualizar_insignia()
	_actualizar_indicador_leccion()


func _aplicar_parametros_visuales() -> void:
	if state_icon == null:
		return
	if icon_scale != Vector2.ZERO:
		state_icon.scale = icon_scale
	if icon_offset != Vector2.ZERO:
		state_icon.position = icon_offset
	if icon_material != null:
		state_icon.material = icon_material
	if badge_offset != Vector2.ZERO and node_badge != null:
		node_badge.position = badge_offset


func _actualizar_insignia() -> void:
	if node_badge == null or Engine.is_editor_hint():
		return
	var is_completed: bool = (visual_state == STATE_COMPLETED) or debug_completed
	node_badge.visible = is_completed
	# Si el nodo está completado, la estrella siempre se muestra llena (dorada).
	# La precisión exacta se puede consultar en la pantalla de estadísticas; aquí
	# solo importa indicar "hecho" vs "no hecho" de forma inequívoca.
	var effective_progress: float
	if debug_progress >= 0.0:
		effective_progress = debug_progress
	elif is_completed:
		# Relleno proporcional a la precisión real del jugador.
		# La estrella solo es visible cuando is_completed=true, así que
		# "hay estrella" = completado; "qué tan llena" = qué tan bien lo hizo.
		effective_progress = clampf(_best_percent, 0.0, 1.0)
	else:
		effective_progress = 0.0
	if DEBUG_BADGES:
		print_debug(
			"[Star] update node_key=",
			node_data.node_key if node_data != null else str(name),
			" percent=",
			effective_progress,
			" completed=",
			is_completed
		)
	if not is_completed:
		return
	if node_badge.has_method("establecer_completado"):
		node_badge.call("establecer_completado", true)
	if node_badge.has_method("establecer_progreso"):
		node_badge.call("establecer_progreso", effective_progress)


func establecer_progreso_estrella(porcentaje: float) -> void:
	_best_percent = clampf(porcentaje, 0.0, 1.0)
	if _best_percent > 0.0:
		_best_accuracy = maxf(_best_accuracy, _best_percent * 100.0)
	if DEBUG_BADGES:
		print_debug(
			"[Star] establecer_progreso node_key=",
			node_data.node_key if node_data != null else node_key,
			" percent=",
			_best_percent
		)
	if node_badge != null and node_badge.has_method("establecer_progreso"):
		node_badge.call("establecer_progreso", _best_percent)
	_actualizar_insignia()


func _on_boton_presionado() -> void:
	if _click_in_progress or Engine.is_editor_hint() or _boton_esta_deshabilitado():
		return
	if node_data == null:
		return

	_click_in_progress = true
	_animar_click()
	await get_tree().create_timer(0.25).timeout
	selected.emit(node_data)
	_click_in_progress = false


func _on_boton_mouse_entrado() -> void:
	if Engine.is_editor_hint() or _is_hovering or _boton_esta_deshabilitado():
		return
	_is_hovering = true
	_animar_escala_hasta(_base_scale * 1.08)


func _on_boton_mouse_salido() -> void:
	if Engine.is_editor_hint() or not _is_hovering:
		return
	_is_hovering = false
	_animar_escala_hasta(_base_scale)


func _obtener_titulo() -> String:
	if node_data != null and not node_data.title.is_empty():
		return node_data.title
	if not label_text.is_empty():
		return label_text
	return name


func _boton_esta_deshabilitado() -> bool:
	return not Engine.is_editor_hint() and not can_play


func _aplicar_color_estado() -> void:
	_cancelar_tween_disponible()
	match visual_state:
		STATE_COMPLETED:
			# Completado: la estrella marca el progreso; el ícono queda neutro (sin halo verde).
			state_icon.modulate = Color.WHITE
			modulate = Color.WHITE
		STATE_AVAILABLE:
			if _es_nodo_recomendado and not completed:
				# Único "siguiente": tono gris-azulado + anillo IndicadorLeccionSiguiente.
				state_icon.modulate = COLOR_AVAILABLE
				modulate = Color.WHITE
			else:
				state_icon.modulate = Color.WHITE
				modulate = COLOR_LOCKED
		_:
			state_icon.modulate = Color.WHITE
			modulate = COLOR_LOCKED


func _asegurar_indicador_leccion() -> void:
	if _indicador_leccion != null and is_instance_valid(_indicador_leccion):
		return
	_indicador_leccion = get_node_or_null("IndicadorLeccionSiguiente") as Node2D
	if _indicador_leccion == null and INDICADOR_LECCION_SCENE != null:
		_indicador_leccion = INDICADOR_LECCION_SCENE.instantiate() as Node2D
		if _indicador_leccion != null:
			_indicador_leccion.name = "IndicadorLeccionSiguiente"
			add_child(_indicador_leccion)


func _actualizar_indicador_leccion() -> void:
	if _indicador_leccion == null or Engine.is_editor_hint():
		return
	var mostrar: bool = (
		_es_nodo_recomendado
		and visual_state == STATE_AVAILABLE
		and not completed
	)
	if _indicador_leccion.has_method("establecer_activo"):
		var numero_leccion: int = _obtener_numero_leccion()
		_indicador_leccion.call(
			"establecer_activo",
			mostrar,
			numero_leccion,
			_obtener_titulo(),
			_obtener_radio_anillo()
		)
	_indicador_activo_previo = mostrar


func _obtener_radio_anillo() -> float:
	if button != null:
		return maxf(button.size.x, button.size.y) * 0.48
	return 78.0


func _obtener_numero_leccion() -> int:
	if node_data != null and node_data.order > 0:
		return node_data.order
	if level_number > 0:
		return level_number
	if question_number > 0:
		return question_number
	return max(1, nivel_id)


func _aplicar_estado_progreso(progress_state: Dictionary) -> void:
	var is_unlocked: bool = bool(progress_state.get("is_unlocked", false))
	var is_completed: bool = bool(progress_state.get("is_completed", false))
	_es_nodo_recomendado = bool(progress_state.get("is_recommended", false))
	# _best_accuracy primero para que los setters con actualizar_vista() ya lo vean correcto
	_best_accuracy = float(progress_state.get("best_accuracy", 0.0))
	_best_percent = float(progress_state.get("best_percent", _best_accuracy / 100.0))
	if is_completed and _best_percent <= 0.0:
		_best_percent = 1.0
		_best_accuracy = maxf(_best_accuracy, 100.0)
	unlocked = is_unlocked
	completed = is_completed
	can_play = bool(progress_state.get("can_play", is_unlocked or is_completed))
	visual_state = _resolver_nombre_estado_visual(
		is_unlocked,
		is_completed,
		str(progress_state.get("visual_state", ""))
	)


func _aplicar_estado_progreso_legado(is_unlocked: bool, is_completed: bool) -> void:
	_es_nodo_recomendado = false
	unlocked = is_unlocked
	completed = is_completed
	can_play = is_unlocked or is_completed
	visual_state = _resolver_nombre_estado_visual(is_unlocked, is_completed)


func _resolver_nombre_estado_visual(
	is_unlocked: bool,
	is_completed: bool,
	state_name: String = ""
) -> String:
	var clean_state_name: String = state_name.strip_edges()
	if not clean_state_name.is_empty():
		return _sanitizar_estado_visual(clean_state_name)
	if is_completed:
		return STATE_COMPLETED
	if is_unlocked:
		return STATE_AVAILABLE
	return STATE_LOCKED


func _sanitizar_estado_visual(state_name: String) -> String:
	match state_name.strip_edges():
		STATE_COMPLETED:
			return STATE_COMPLETED
		STATE_AVAILABLE:
			return STATE_AVAILABLE
		_:
			return STATE_LOCKED


func _cancelar_tween_disponible() -> void:
	if _disponible_tween != null:
		_disponible_tween.kill()
	_disponible_tween = null


func _animar_disponible() -> void:
	_cancelar_tween_disponible()
	_disponible_tween = create_tween()
	_disponible_tween.set_trans(Tween.TRANS_BACK)
	_disponible_tween.set_ease(Tween.EASE_OUT)
	_disponible_tween.tween_property(self, "scale", _base_scale * 1.18, 0.4)
	_disponible_tween.tween_property(self, "scale", _base_scale, 0.3)


func _animar_escala_hasta(escala_destino: Vector2) -> void:
	if _es_nodo_recomendado and visual_state == STATE_AVAILABLE:
		escala_destino = _base_scale
	var tween := create_tween()
	tween.tween_property(self, "scale", escala_destino, 0.12)


func _animar_click() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * Vector2(1.15, 0.90), 0.06)
	tween.tween_property(self, "scale", _base_scale * Vector2(0.95, 1.05), 0.06)
	tween.tween_property(self, "scale", _base_scale, 0.08)
