class_name MobileUiLayoutHelper
extends RefCounted

# Utilidades compartidas para adaptar UI a pantallas chicas (web móvil / itch.io).

const BREAKPOINT_ESTRECHO := 760.0
const MARGEN_PANTALLA := 16.0
const MIN_TOUCH := 44.0
const DISENO_ANCHO := 1152.0
const DISENO_ALTO := 800.0


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
	var estrecho := es_pantalla_estrecha_viewport(viewport.x)
	var escala := escala_base
	if estrecho:
		escala = clampf((viewport.x - margen * 2.0) / ancho_base, 0.48, escala_base)
	control.scale = Vector2(escala, escala)
	var ancho_visual := ancho_base * escala
	control.position = Vector2(
		(viewport.x - ancho_visual) * 0.5,
		posicion_y_base * (viewport.y / DISENO_ALTO)
	)


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
	tamano: float = MIN_TOUCH,
	margen: float = MARGEN_PANTALLA
) -> void:
	if not is_instance_valid(boton):
		return
	boton.scale = Vector2.ONE
	boton.size = Vector2(tamano, tamano)
	boton.position = Vector2(margen, viewport.y - tamano - margen)


static func cerrar_si_toque_fondo(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return false
