class_name MobileUiLayoutHelper
extends RefCounted

# Utilidades compartidas para adaptar UI a pantallas chicas (web móvil / itch.io).

const BREAKPOINT_ESTRECHO := 760.0
const MARGEN_PANTALLA := 16.0
const MIN_TOUCH := 44.0
const DISENO_ANCHO := 1152.0
const DISENO_ALTO := 800.0
const TAMANO_BOTON_VOLVER := 48.0
const ANCHO_SCROLL_DISCRETO := 5.0

static var _scroll_styles_ready := false
static var _scroll_style_bg: StyleBoxFlat
static var _scroll_style_grabber: StyleBoxFlat
static var _scroll_style_grabber_hover: StyleBoxFlat


static func es_pantalla_estrecha(control: Control, umbral: float = BREAKPOINT_ESTRECHO) -> bool:
	if not is_instance_valid(control):
		return false
	return control.size.x < umbral


static func es_pantalla_estrecha_viewport(ancho: float, umbral: float = BREAKPOINT_ESTRECHO) -> bool:
	return ancho < umbral


static func clamp_ancho_contenido(
	ancho_viewport: float,
	margen_horizontal: float = 40.0,
	min_ancho: float = 280.0,
	max_ancho: float = 560.0
) -> float:
	return clampf(ancho_viewport - margen_horizontal, min_ancho, max_ancho)


static func aplicar_margenes_uniformes(
	margin_container: MarginContainer,
	estrecho: bool,
	margen_ancho: int,
	margen_estrecho: int
) -> void:
	if not is_instance_valid(margin_container):
		return
	var margen := margen_estrecho if estrecho else margen_ancho
	margin_container.add_theme_constant_override("margin_left", margen)
	margin_container.add_theme_constant_override("margin_right", margen)
	margin_container.add_theme_constant_override("margin_top", margen)
	margin_container.add_theme_constant_override("margin_bottom", margen)


static func aplicar_panel_lateral(
	panel: Control,
	ancho_viewport: float,
	ancho_desktop: float = 704.0,
	margen_derecho: float = MARGEN_PANTALLA,
	umbral: float = BREAKPOINT_ESTRECHO
) -> void:
	if not is_instance_valid(panel):
		return
	if ancho_viewport < umbral:
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.offset_left = 0.0
		panel.offset_right = 0.0
		return
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -ancho_desktop
	panel.offset_right = -margen_derecho


static func offset_cerrado_panel_lateral(
	ancho_viewport: float,
	ancho_desktop: float = 704.0,
	umbral: float = BREAKPOINT_ESTRECHO
) -> float:
	if ancho_viewport < umbral:
		return ancho_viewport
	return -(ancho_desktop - MARGEN_PANTALLA)


static func aplicar_rect_completo(control: Control, viewport: Vector2) -> void:
	if not is_instance_valid(control):
		return
	control.position = Vector2.ZERO
	control.size = viewport


static func aplicar_modal_centrado(
	panel: Control,
	viewport: Vector2,
	ancho_max: float = 600.0,
	alto_max: float = 760.0
) -> void:
	if not is_instance_valid(panel):
		return
	var ancho := clamp_ancho_contenido(viewport.x, 24.0, 280.0, ancho_max)
	var alto := clampf(viewport.y - 24.0, 280.0, minf(alto_max, viewport.y - 24.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -ancho * 0.5
	panel.offset_top = -alto * 0.5
	panel.offset_right = ancho * 0.5
	panel.offset_bottom = alto * 0.5


static func centrar_control_escalado(
	control: Control,
	viewport: Vector2,
	ancho_base: float,
	escala_base: float,
	posicion_y_base: float,
	margen: float = MARGEN_PANTALLA
) -> void:
	if not is_instance_valid(control):
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.set_offsets_preset(Control.PRESET_TOP_LEFT)
	var estrecho := es_pantalla_estrecha_viewport(viewport.x)
	var escala := escala_base
	if estrecho:
		escala = clampf((viewport.x - margen * 2.0) / ancho_base, 0.42, escala_base)
	control.scale = Vector2(escala, escala)
	var ancho_visual := ancho_base * escala
	var posicion_x := maxf(margen, (viewport.x - ancho_visual) * 0.5)
	var posicion_y := posicion_y_base * (viewport.y / DISENO_ALTO)
	control.position = Vector2(posicion_x, posicion_y)
	control.size = Vector2(ancho_base, control.size.y if control.size.y > 0.0 else ancho_base)


static func centrar_label_horizontal(label: Label, viewport: Vector2, posicion_y: float) -> void:
	if not is_instance_valid(label):
		return
	var ancho_texto := label.get_minimum_size().x
	if ancho_texto <= 0.0:
		ancho_texto = label.size.x
	label.position.x = maxf(MARGEN_PANTALLA, (viewport.x - ancho_texto) * 0.5)
	label.position.y = posicion_y


static func configurar_boton_volver(boton: BaseButton, tamano: float = TAMANO_BOTON_VOLVER) -> void:
	if not is_instance_valid(boton):
		return
	boton.scale = Vector2.ONE
	boton.custom_minimum_size = Vector2(tamano, tamano)
	boton.size = Vector2(tamano, tamano)
	boton.expand_icon = true
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	boton.clip_contents = true
	boton.focus_mode = Control.FOCUS_NONE


static func _asegurar_estilos_scroll() -> void:
	if _scroll_styles_ready:
		return
	_scroll_style_bg = StyleBoxFlat.new()
	_scroll_style_bg.bg_color = Color(0.12, 0.13, 0.12, 0.05)
	_scroll_style_bg.set_corner_radius_all(4)

	_scroll_style_grabber = StyleBoxFlat.new()
	_scroll_style_grabber.bg_color = Color(0.22, 0.24, 0.22, 0.22)
	_scroll_style_grabber.set_corner_radius_all(4)

	_scroll_style_grabber_hover = _scroll_style_grabber.duplicate() as StyleBoxFlat
	_scroll_style_grabber_hover.bg_color = Color(0.22, 0.24, 0.22, 0.38)
	_scroll_styles_ready = true


static func estilizar_scroll_discreto(scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll):
		return
	_asegurar_estilos_scroll()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return
	var barra := scroll.get_v_scroll_bar()
	if barra == null:
		return
	barra.custom_minimum_size.x = ANCHO_SCROLL_DISCRETO
	barra.add_theme_stylebox_override("scroll", _scroll_style_bg)
	barra.add_theme_stylebox_override("grabber", _scroll_style_grabber)
	barra.add_theme_stylebox_override("grabber_highlight", _scroll_style_grabber_hover)
	barra.add_theme_stylebox_override("grabber_pressed", _scroll_style_grabber_hover)


static func asegurar_minimo_tactil(control: Control, min_size: float = MIN_TOUCH) -> void:
	if not is_instance_valid(control):
		return
	control.custom_minimum_size = Vector2(
		maxf(control.custom_minimum_size.x, min_size),
		maxf(control.custom_minimum_size.y, min_size)
	)


static func posicionar_boton_esquina_inferior_izquierda(
	boton: Control,
	viewport: Vector2,
	tamano: float = TAMANO_BOTON_VOLVER,
	margen: float = MARGEN_PANTALLA
) -> void:
	if not is_instance_valid(boton):
		return
	if boton is BaseButton:
		configurar_boton_volver(boton as BaseButton, tamano)
	else:
		boton.scale = Vector2.ONE
		boton.custom_minimum_size = Vector2(tamano, tamano)
		boton.size = Vector2(tamano, tamano)
	boton.position = Vector2(margen, viewport.y - tamano - margen)


static func cerrar_si_toque_fondo(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return false
