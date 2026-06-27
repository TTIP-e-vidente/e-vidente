extends PanelContainer

# Casilla visual de un dígito del código de verificación.


const COLOR_VACIO := Color(0.259, 0.471, 0.369, 0.4)
const COLOR_LLENO := Color(0.18, 0.34, 0.26, 1.0)
const COLOR_BORDE_VACIO := Color(0.259, 0.471, 0.369, 0.35)
const COLOR_BORDE_LLENO := Color(0.259, 0.471, 0.369, 0.85)


@onready var _label: Label = %DigitLabel

var _panel_style: StyleBoxFlat


func _ready() -> void:
	var base := get_theme_stylebox("panel") as StyleBoxFlat
	if base != null:
		_panel_style = base.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("panel", _panel_style)


func mostrar_caracter(caracter: String) -> void:
	if not is_instance_valid(_label):
		return
	var lleno := not caracter.is_empty()
	_label.text = caracter if lleno else "·"
	_label.add_theme_color_override("font_color", COLOR_LLENO if lleno else COLOR_VACIO)
	if _panel_style != null:
		_panel_style.border_color = COLOR_BORDE_LLENO if lleno else COLOR_BORDE_VACIO
