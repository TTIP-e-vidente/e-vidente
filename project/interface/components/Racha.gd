@tool
class_name Racha
extends Control

signal pressed

const SPRAY_TEXTURE := preload("res://assets-sistema/racha-diaria/racha-diaria.png")
const COUNT_FONT := preload("res://fonts/RubikSprayPaint-Regular.ttf")
const ACTIVE_TEXTURE := preload("res://assets-sistema/racha-diaria/racha-activa.png")
const WARNING_TEXTURE := preload("res://assets-sistema/racha-diaria/racha-warning.png")
const INACTIVE_TEXTURE := preload("res://assets-sistema/racha-diaria/racha-inactiva.png")

var _current_count: int = 0
var _streak_state: String = "inactive"
var _is_interactive := true

@onready var background: TextureRect = $Background
@onready var count_label: Label = $CountLabel
@onready var hotspot_button: Button = $HotspotButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configurar_nodos_escena()
	_configurar_boton_hotspot()
	renderizar()


func renderizar(streak_view_model: Dictionary = {}) -> void:
	_aplicar_view_model(_resolver_view_model(streak_view_model))


func render(streak_view_model: Dictionary = {}) -> void:
	renderizar(streak_view_model)


func establecer_insignia(number_value: int, _next_status_key: String = "") -> void:
	_current_count = max(0, number_value)
	_refrescar_ui()


func establecer_interactivo(enabled: bool) -> void:
	_is_interactive = enabled
	_refrescar_interactividad()


func _resolver_view_model(streak_view_model: Dictionary) -> Dictionary:
	if not streak_view_model.is_empty():
		return streak_view_model
	var global_node := get_node_or_null("/root/Global")
	if global_node and global_node.has_method("obtener_modelo_vista_racha"):
		return global_node.obtener_modelo_vista_racha()
	return {}


func _aplicar_view_model(streak_view_model: Dictionary) -> void:
	_current_count = max(
		0,
		int(streak_view_model.get("current_count", 0))
	)

	_streak_state = str(
		streak_view_model.get("streak_state", "inactive")
	)

	_refrescar_ui()


func _configurar_nodos_escena() -> void:
	if background != null:
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.offset_left = 0.0
		background.offset_top = 0.0
		background.offset_right = 0.0
		background.offset_bottom = 0.0
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.texture = SPRAY_TEXTURE
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if count_label != null:
		count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		count_label.offset_left = 0.0
		count_label.offset_top = 0.0
		count_label.offset_right = 0.0
		count_label.offset_bottom = 0.0
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_override("font", COUNT_FONT)
		count_label.add_theme_color_override("font_color", Color(0, 0, 0, 1.0))

	_refrescar_ui()


func _configurar_boton_hotspot() -> void:
	if hotspot_button == null:
		return
	hotspot_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	hotspot_button.offset_left = 0.0
	hotspot_button.offset_top = 0.0
	hotspot_button.offset_right = 0.0
	hotspot_button.offset_bottom = 0.0
	hotspot_button.flat = true
	hotspot_button.text = ""
	hotspot_button.focus_mode = Control.FOCUS_ALL
	hotspot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	hotspot_button.add_theme_stylebox_override("normal", empty_style)
	hotspot_button.add_theme_stylebox_override("hover", empty_style)
	hotspot_button.add_theme_stylebox_override("pressed", empty_style)
	hotspot_button.add_theme_stylebox_override("focus", empty_style)
	hotspot_button.add_theme_stylebox_override("disabled", empty_style)
	if not hotspot_button.pressed.is_connected(_on_boton_hotspot_presionado):
		hotspot_button.pressed.connect(_on_boton_hotspot_presionado)
	_refrescar_interactividad()


func _refrescar_ui() -> void:
	if not is_node_ready():
		return

	if count_label != null:
		var count_text := str(_current_count)

		count_label.text = count_text

		count_label.add_theme_font_size_override(
			"font_size",
			_resolver_tamano_fuente_contador(count_text)
		)
		_aplicar_estado_visual()


func _aplicar_estado_visual() -> void:
	match _streak_state:
		"active":
			_estado_activo()

		"warning":
			_estado_warning()

		"inactive":
			_estado_inactivo()


func _resolver_tamano_fuente_contador(count_text: String) -> int:
	if count_text.length() >= 3:
		return 34
	if count_text.length() == 2:
		return 42
	return 52


func _refrescar_interactividad() -> void:
	if hotspot_button == null:
		return
	hotspot_button.visible = _is_interactive
	hotspot_button.disabled = not _is_interactive


func _estado_activo() -> void:
	background.texture = ACTIVE_TEXTURE
	modulate = Color.WHITE


func _estado_warning() -> void:
	background.texture = WARNING_TEXTURE
	modulate = Color.WHITE


func _estado_inactivo() -> void:
	background.texture = INACTIVE_TEXTURE
	modulate = Color(0.8, 0.8, 0.8)


func _on_boton_hotspot_presionado() -> void:
	pressed.emit()
